"""Build a portable Windows x64 launcher + Godot export without private game assets."""
import argparse
import hashlib
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import zipfile
from datetime import datetime, timezone

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT))

def build_environment():
    # Native libraries from unrelated tools must not enter the frozen app.
    env={k:v for k,v in os.environ.items() if not k.upper().startswith(('PYTHON','QT_','QML'))}
    windows=next((v for k,v in os.environ.items() if k.upper()=='SYSTEMROOT'),'C:/Windows')
    env['PATH']=os.pathsep.join([str(Path(sys.executable).parent),str(Path(sys.base_prefix)),str(Path(windows)/'System32'),windows])
    return env

def run(command):
    print('Running: '+subprocess.list2cmdline([str(v) for v in command]),flush=True)
    subprocess.run([str(v) for v in command],cwd=ROOT,check=True,env=build_environment())

def check_launcher(folder, report):
    report.unlink(missing_ok=True)
    startup=subprocess.STARTUPINFO()
    startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
    startup.wShowWindow=0
    subprocess.run([str(folder/'Diablo Survivors.exe'),'--startup-check',str(report)],cwd=report.parent,env=build_environment(),startupinfo=startup,check=True,timeout=30,capture_output=True)
    if report.read_text(encoding='utf-8')!='QT_STARTUP_OK':raise ValueError('Qt setup window failed its startup check')

def clean_build_folder(path):
    resolved=path.resolve()
    allowed=(ROOT/'.local/windows-build').resolve()
    if resolved==allowed or not resolved.is_relative_to(allowed) or not resolved.is_relative_to(ROOT.resolve()):
        raise ValueError('Refusing to remove path outside build workspace: '+str(resolved))
    if path.exists():shutil.rmtree(path)

def zip_release(destination):
    from manager.version import APP_VERSION
    name='Diablo_Survivors_v'+APP_VERSION.replace(' ','_')+'_Windows_x64.zip'
    archive_path=destination/name
    temporary=ROOT/'.local/windows-build'/('packaging-'+name)
    temporary.parent.mkdir(parents=True,exist_ok=True)
    library=destination/'_internal/base_library.zip'
    if not library.is_file():raise ValueError('Release is missing the embedded Python standard library: '+str(library))
    with zipfile.ZipFile(library) as standard_library:
        if 'encodings/__init__.pyc' not in standard_library.namelist():raise ValueError('Embedded Python standard library is missing encodings')
    with zipfile.ZipFile(temporary,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as archive:
        for path in sorted(destination.rglob('*')):
            relative=path.relative_to(destination)
            # Only omit distribution archives at the root. Nested ZIPs can be required runtime files.
            if not path.is_file() or (len(relative.parts)==1 and path.suffix.lower()=='.zip') or any(part in ('.local','.godot','__pycache__') for part in relative.parts):continue
            if path.suffix.lower() in ('.mpq','.d2s'):raise ValueError('Private game file in release: '+str(path))
            archive.write(path,Path('Diablo Survivors')/relative)
    with zipfile.ZipFile(temporary) as archive:
        if archive.testzip() is not None:raise ValueError('Release ZIP integrity check failed')
        bundled_library=archive.read('Diablo Survivors/_internal/base_library.zip')
        if hashlib.sha256(bundled_library).digest()!=hashlib.sha256(library.read_bytes()).digest():raise ValueError('Packaged Python standard library differs from build output')
        with zipfile.ZipFile(io.BytesIO(bundled_library)) as standard_library:
            if 'encodings/__init__.pyc' not in standard_library.namelist():raise ValueError('Release ZIP is missing Python encodings')
    temporary.replace(archive_path)
    print('Distribution ZIP: '+str(archive_path),flush=True)
    return archive_path

def main():
    from manager.version import APP_VERSION
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot',help='Godot 4.6.2 editor executable')
    parser.add_argument('--template',help='Godot 4.6.2 windows_release_x86_64.exe export template')
    parser.add_argument('--stormlib',help='64-bit StormLib.dll')
    parser.add_argument('--zip',action='store_true',help='Accepted for compatibility; a distribution ZIP is always created')
    args=parser.parse_args()
    if sys.platform!='win32' or sys.maxsize<=2**32:raise SystemExit('Build using 64-bit Python on Windows.')
    from manager.services.runtime import find_godot
    godot=Path(find_godot(args.godot or ''))
    version=subprocess.check_output([str(godot),'--version'],text=True).strip()
    if not version.startswith('4.6.2.'):raise SystemExit('This build requires Godot 4.6.2.')
    template=Path(args.template or os.environ.get('GODOT_EXPORT_TEMPLATE','') or Path(os.environ['APPDATA'])/'Godot/export_templates/4.6.2.stable/windows_release_x86_64.exe').resolve()
    storm=Path(args.stormlib or ROOT/'.tools/stormlib-9.40/x64/StormLib.dll').resolve()
    for path in [template,storm]:
        if not path.is_file():raise SystemExit(f'Missing build dependency: {path}. See docs/windows_release.md.')
    subprocess.run([sys.executable,'-m','PyInstaller','--version'],check=True)
    work=ROOT/'.local/windows-build'
    stage=work/'runtime';work.mkdir(parents=True,exist_ok=True)
    clean_build_folder(stage)
    shutil.copytree(ROOT/'runtime',stage,ignore=shutil.ignore_patterns('.godot','tests','*.uid','*.import','--d2-manifest'))
    output=work/'output';output.mkdir(exist_ok=True)
    preset='''[preset.0]
name="Windows Release"
platform="Windows Desktop"
runnable=true
export_filter="all_resources"
include_filter="*.json"
exclude_filter="tests/*"
export_path=""
[preset.0.options]
custom_template/debug=""
custom_template/release=%s
binary_format/architecture="x86_64"
binary_format/embed_pck=false
debug/export_console_wrapper=0
codesign/enable=false
''' % json.dumps(template.as_posix())
    (stage/'export_presets.cfg').write_text(preset,encoding='utf-8')
    game=output/'game/DiabloSurvivorsGame.exe';game.parent.mkdir(exist_ok=True)
    run([godot,'--headless','--path',stage,'--editor','--import','--log-file',work/'godot-import.log'])
    run([godot,'--headless','--path',stage,'--export-release','Windows Release',game,'--log-file',work/'godot-export.log'])
    if not game.is_file() or not game.with_suffix('.pck').is_file():raise SystemExit('Godot export is incomplete.')
    run([sys.executable,'-m','PyInstaller','--noconfirm','--clean','--onedir','--windowed','--name','Diablo Survivors','--distpath',work/'dist','--workpath',work/'pyinstaller','--specpath',work,'--paths',ROOT,'--collect-submodules','adapters','--collect-submodules','inspector','--collect-submodules','manager','--hidden-import','scripts.run_survival_demo','--hidden-import','scripts.run_imported_demo',ROOT/'scripts/run_gameshift.py'])
    assembled=work/'assembled'
    clean_build_folder(assembled)
    shutil.copytree(work/'dist/Diablo Survivors',assembled)
    shutil.copytree(output/'game',assembled/'game')
    for folder in ['profiles','catalogs','schemas']:
        shutil.copytree(ROOT/folder,assembled/folder)
    if (ROOT/'extras').is_dir():
        shutil.copytree(ROOT/'extras',assembled/'extras',ignore=shutil.ignore_patterns('*.import','*.uid'))
    resources=assembled/'runtime/resources';resources.mkdir(parents=True)
    for filename in ['upgrades.json','zones.json']:
        shutil.copy2(ROOT/'runtime/resources'/filename,resources/filename)
    native=assembled/'.tools/stormlib-9.40/x64';native.mkdir(parents=True)
    shutil.copy2(storm,native/'StormLib.dll')
    for filename in ['LICENSE','THIRD_PARTY_NOTICES.md']:
        shutil.copy2(ROOT/filename,assembled/filename)
    shutil.copytree(ROOT/'docs/licenses',assembled/'licenses')
    notices=assembled/'THIRD_PARTY_NOTICES.md'
    notices.write_text(notices.read_text(encoding='utf-8').replace('docs/licenses/','licenses/').replace('adapters/diablo2/DIABLERIE_LICENSE.txt','DIABLERIE_LICENSE.txt'),encoding='utf-8')
    shutil.copy2(ROOT/'adapters/diablo2/DIABLERIE_LICENSE.txt',assembled/'DIABLERIE_LICENSE.txt')
    (assembled/'build_info.json').write_text(json.dumps({'app_version':APP_VERSION,'built_utc':datetime.now(timezone.utc).isoformat(),'godot':version,'python':sys.version,'stormlib_sha256':hashlib.sha256(storm.read_bytes()).hexdigest()},indent=2),encoding='utf-8')
    (assembled/'START_HERE.txt').write_text('Run Diablo Survivors.exe. Choose your installed Diablo game.\nNo Python or Godot installation is required.\nKeep the complete folder together. Caches and saves are in .local beside the launcher.\nThe folder must be writable. Original game archives are not included.\n',encoding='utf-8')
    from manager.version import APP_TITLE
    (assembled/'README.md').write_text('# '+APP_TITLE+'\n\nRun **Diablo Survivors.exe** in this folder, choose your installed game, and allow a few minutes for the first asset import. Python and Godot are bundled.\n\nKeep the complete folder together in a writable location. Your cache and progress are stored in `.local` beside the launcher. If startup fails, check `.local/logs/launcher.log` and `.local/logs/game.log`.\n\nDiablo I, classic Diablo II, and Lord of Destruction are supported. Diablo II and LoD work with the original CD versions; Battle.net versions have not been tested. Diablo II: Resurrected / Infernal Edition is not supported.\n',encoding='utf-8')
    check_launcher(assembled,work/'qt-startup.txt')
    forbidden=[p for p in assembled.rglob('*') if p.suffix.lower() in ('.mpq','.d2s') or '.local' in p.relative_to(assembled).parts]
    if forbidden:raise SystemExit('Unexpected private files in release: '+str(forbidden))
    destination=ROOT/'build_release'
    if destination.resolve().parent!=ROOT.resolve():raise SystemExit('Release destination must be inside the project folder.')
    if destination.exists():
        backup=work/'previous-release'
        if backup.exists():backup=work/('previous-release-'+datetime.now(timezone.utc).strftime('%Y%m%d-%H%M%S-%f'))
        shutil.move(str(destination),str(backup))
    shutil.copytree(assembled,destination)
    zip_release(destination)
    print('Built '+str(destination))

if __name__=='__main__':main()
