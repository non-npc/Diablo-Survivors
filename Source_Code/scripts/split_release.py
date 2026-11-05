"""Split the built release for GitHub's per-file limit."""
from pathlib import Path
import hashlib
import shutil

ROOT = Path(__file__).resolve().parents[1]

def main():
    from sys import path
    path.insert(0, str(ROOT))
    from manager.version import APP_VERSION
    name = 'Diablo_Survivors_v' + APP_VERSION.replace(' ', '_') + '_Windows_x64.zip'
    source = ROOT / 'build_release' / name
    target = ROOT / 'github_final'
    data = source.read_bytes()
    midpoint = (len(data) + 1) // 2
    parts = [target / (name + '.part1'), target / (name + '.part2')]
    for part, payload in zip(parts, (data[:midpoint], data[midpoint:])):
        if len(payload) >= 100_000_000:
            raise ValueError('Two parts exceed the 100 MB limit')
        part.write_bytes(payload)
    digest = hashlib.sha256()
    for part in parts:
        digest.update(part.read_bytes())
    assert digest.digest() == hashlib.sha256(data).digest()
    batch = '@echo off\ncd /d "%~dp0"\n'
    batch += f'if not exist "{parts[0].name}" goto missing\nif not exist "{parts[1].name}" goto missing\n'
    batch += f'copy /b "{parts[0].name}"+"{parts[1].name}" "{name}"\n'
    batch += 'if errorlevel 1 exit /b 1\necho ZIP joined successfully. Extract the ZIP, then run Diablo Survivors.exe.\npause\nexit /b 0\n:missing\necho Download both release parts into this folder first.\npause\nexit /b 1\n'
    (target / 'Join_Release.bat').write_text(batch, encoding='ascii', newline='\r\n')
    # Keep complete archives outside the GitHub upload folder.
    archive = ROOT / '.local/release-archives'
    archive.mkdir(parents=True, exist_ok=True)
    for old in target.glob('*.zip'):
        destination = archive / old.name
        if destination.exists():
            assert hashlib.sha256(destination.read_bytes()).digest() == hashlib.sha256(old.read_bytes()).digest()
            old.unlink()
        else:
            shutil.move(str(old), str(destination))
    readme = target / 'README.md'
    text = readme.read_text(encoding='utf-8')
    start = text.index('## Download Latest Version')
    end = text.index('**First-time setup', start)
    replacement = f'## Download Latest Version\n\nDownload both parts of **v{APP_VERSION}** into the same folder:\n\n- [Part 1]({parts[0].name})\n- [Part 2]({parts[1].name})\n- [Join_Release.bat](Join_Release.bat)\n\nRun **Join_Release.bat** to combine the parts into `{name}`, then extract that ZIP and run **Diablo Survivors.exe**. The two parts are pieces of one ZIP and cannot be extracted separately.\n\n'
    readme.write_text(text[:start] + replacement + text[end:], encoding='utf-8')
    for part in parts:
        print(f'{part.name}: {part.stat().st_size:,} bytes')
    print('Joined SHA-256 verified:', digest.hexdigest())

if __name__ == '__main__':
    main()
