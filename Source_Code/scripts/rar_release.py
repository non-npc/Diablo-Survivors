"""Create two RAR volumes for the GitHub distribution folder."""
from pathlib import Path
import subprocess
import shutil
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from manager.version import APP_VERSION

def main():
    rar = Path('C:/Program Files/WinRAR/Rar.exe')
    if not rar.is_file():
        raise SystemExit('Install WinRAR to build the multipart RAR release.')
    name = 'Diablo_Survivors_v' + APP_VERSION.replace(' ', '_') + '_Windows_x64'
    stage = ROOT / '.local/rar-distribution' / name
    stage.mkdir(parents=True, exist_ok=True)
    archive = stage / (name + '.rar')
    subprocess.run([str(rar), 'a', '-m0', '-v65000000b', '-ep1', '-idq', str(archive), str(ROOT / 'build_release' / (name + '.zip'))], check=True)
    parts = sorted(stage.glob(name + '.part*.rar'))
    assert len(parts) == 2, parts
    subprocess.run([str(rar), 't', '-idq', str(parts[0])], check=True)
    target = ROOT / 'github_final'
    for part in parts:
        assert part.stat().st_size < 100_000_000
        shutil.copy2(part, target / part.name)
    backup = ROOT / '.local/release-archives/split-zip'
    backup.mkdir(parents=True, exist_ok=True)
    for old in [*target.glob('*.zip.part*'), target / 'Join_Release.bat']:
        if old.exists():
            shutil.move(str(old), str(backup / old.name))
    readme = target / 'README.md'
    text = readme.read_text(encoding='utf-8')
    start = text.index('## Download Latest Version')
    end = text.index('**First-time setup', start)
    section = f'## Download Latest Version\n\nDownload both RAR volumes of **v{APP_VERSION}** into the same folder:\n\n- [Part 1]({parts[0].name})\n- [Part 2]({parts[1].name})\n\nOpen **Part 1** with WinRAR or 7-Zip and extract it; Part 2 is read automatically. Then extract the included ZIP and run **Diablo Survivors.exe**. Both parts are required.\n\n'
    readme.write_text(text[:start] + section + text[end:], encoding='utf-8')
    for part in parts:
        print(part.name, part.stat().st_size)

if __name__ == '__main__':
    main()
