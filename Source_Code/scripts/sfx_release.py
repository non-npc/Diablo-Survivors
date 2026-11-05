"""Build a multipart, extraction-only Windows package using WinRAR."""
from pathlib import Path
import hashlib
import shutil
import subprocess
import sys
import os
import zipfile
from datetime import datetime
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from manager.version import APP_VERSION

def omit_distribution_archives(source, folder, names):
    return [name for name in names if name == '.local' or (Path(folder) == Path(source) and name.lower().endswith('.zip'))]

def main():
    rar = Path('C:/Program Files/WinRAR/Rar.exe')
    sfx = rar.parent / 'Default.SFX'
    if not rar.is_file() or not sfx.is_file():
        raise SystemExit('Install WinRAR with Default.SFX to build this package.')
    name = 'Diablo_Survivors_v' + APP_VERSION.replace(' ', '_') + '_Windows_x64_Setup'
    work = ROOT / '.local/sfx-distribution' / datetime.now().strftime('%Y%m%d-%H%M%S-%f')
    payload = work / 'payload'
    payload.mkdir(parents=True)
    source = ROOT / 'build_release'
    shutil.copytree(source, payload / 'Diablo Survivors', ignore=lambda folder, names: omit_distribution_archives(source, folder, names))
    library = payload / 'Diablo Survivors/_internal/base_library.zip'
    with zipfile.ZipFile(library) as bundled:
        assert 'encodings/__init__.pyc' in bundled.namelist(), 'Missing Python encodings module'
    config = work / 'sfx.txt'
    config.write_text('; WinRAR SFX commands\nPath=%USERPROFILE%\\Games\\Diablo Survivors\nTitle=Diablo Survivors v' + APP_VERSION + ' - Extract game\nText\n{\nChoose a writable folder for Diablo Survivors. After extraction, open the Diablo Survivors folder and run Diablo Survivors.exe when ready.\n}\n', encoding='utf-8')
    archive = work / (name + '.exe')
    subprocess.run([str(rar), 'a', '-r', '-m3', '-v65000000b', '-sfx' + str(sfx), '-z' + str(config), '-idq', str(archive), 'Diablo Survivors'], cwd=payload, check=True)
    parts = sorted(work.glob(name + '.part*'))
    assert len(parts) == 2, parts
    first = next(p for p in parts if p.suffix == '.exe')
    subprocess.run([str(rar), 't', '-idq', str(first)], check=True)
    extracted = work / 'verified'
    subprocess.run([str(rar), 'x', '-idq', str(first), str(extracted) + '/'], check=True)
    files = [p for p in (payload / 'Diablo Survivors').rglob('*') if p.is_file()]
    for original in files:
        restored = extracted / original.relative_to(payload)
        assert hashlib.sha256(original.read_bytes()).digest() == hashlib.sha256(restored.read_bytes()).digest(), original
    startup = subprocess.STARTUPINFO()
    startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
    startup.wShowWindow = 0
    env = {k: v for k, v in os.environ.items() if not k.upper().startswith('PYTHON')}
    report = work / 'qt-startup.txt'
    subprocess.run([str(extracted / 'Diablo Survivors/Diablo Survivors.exe'), '--startup-check', str(report)], cwd=work, env=env, startupinfo=startup, timeout=30, check=True, capture_output=True)
    assert report.read_text() == 'QT_STARTUP_OK'
    print('Extracted launcher started successfully with bundled Python.', flush=True)
    target = ROOT / 'github_final'
    backup = ROOT / '.local/release-archives' / work.name
    backup.mkdir(parents=True)
    for old in list(target.glob('*.part*.rar')) + list(target.glob('*Setup.part*.exe')):
        shutil.move(str(old), str(backup / old.name))
    for part in parts:
        assert part.stat().st_size < 100_000_000
        shutil.copy2(part, target / part.name)
    readme = target / 'README.md'
    text = readme.read_text(encoding='utf-8')
    start = text.index('## Download Latest Version')
    end = text.index('**First-time setup', start)
    links = ''.join(f'- [Part {i + 1} ({p.suffix[1:].upper()})]({p.name})\n' for i, p in enumerate(parts))
    section = f'## Download Latest Version\n\nDownload both parts of **v{APP_VERSION}** into the same folder:\n\n{links}\nRun **{first.name}** and choose an extraction folder. The second part is read automatically; WinRAR is not required. After extraction, open the **Diablo Survivors** folder and run **Diablo Survivors.exe** when ready. The extractor does not launch the game. Keep the complete game folder together in a writable location.\n\n'
    readme.write_text(text[:start] + section + text[end:], encoding='utf-8')
    print(f'Verified all {len(files)} extracted files against the build.')
    for part in parts:
        print(part.name, part.stat().st_size)

if __name__ == '__main__':
    main()
