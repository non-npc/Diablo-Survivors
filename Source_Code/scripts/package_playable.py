"""Build the minimal source-based playable distribution, without private game data."""
import ast
import shutil
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
TARGET=ROOT/"github_release"

def main():
    if TARGET.exists() and any(TARGET.iterdir()):
        raise SystemExit("github_release must be empty before packaging; existing files were preserved.")
    TARGET.mkdir(exist_ok=True)
    files=set()
    pending=[ROOT/"scripts/run_gameshift.py",ROOT/"scripts/setup_godot.py",ROOT/"scripts/setup_stormlib.py"]
    while pending:
        path=pending.pop()
        if path in files:continue
        files.add(path)
        # Parent packages are necessary for Python imports.
        for parent in path.parents:
            if parent==ROOT:break
            init=parent/"__init__.py"
            if init.exists():pending.append(init)
        for node in ast.walk(ast.parse(path.read_text(encoding="utf-8-sig"))):
            names=[alias.name for alias in node.names] if isinstance(node,ast.Import) else [node.module] if isinstance(node,ast.ImportFrom) and node.module else []
            for name in names:
                module=ROOT.joinpath(*name.split("."))
                for candidate in [module.with_suffix(".py"),module/"__init__.py"]:
                    if candidate.is_file():pending.append(candidate)
    for tree in ["profiles","catalogs","schemas","runtime/resources","runtime/scripts"]:
        files.update(path for path in (ROOT/tree).rglob("*") if path.is_file() and path.suffix not in {".pyc",".uid",".import"} and "__pycache__" not in path.parts)
    files.update(ROOT/name for name in ["runtime/project.godot","runtime/scenes/survival.tscn","requirements.txt","LICENSE","THIRD_PARTY_NOTICES.md","adapters/diablo2/DIABLERIE_LICENSE.txt","docs/licenses/StormLib-MIT.txt"])
    files.difference_update(ROOT/name for name in ["runtime/scripts/demo.gd","runtime/scripts/import_preview.gd","runtime/resources/demo_manifest.json"])
    for path in sorted(files):
        destination=TARGET/path.relative_to(ROOT);destination.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(path,destination)
    (TARGET/"Run_Diablo_Survivors.bat").write_text('@echo off\ncd /d "%~dp0"\npython scripts\\run_gameshift.py\nif errorlevel 1 pause\n',encoding="utf-8")
    (TARGET/"Setup.bat").write_text('@echo off\ncd /d "%~dp0"\npython -m pip install -r requirements.txt\nif errorlevel 1 goto failed\npython scripts\\setup_godot.py\nif errorlevel 1 goto failed\npython scripts\\setup_stormlib.py\nif errorlevel 1 goto failed\n.tools\\godot-4.6.2\\Godot_v4.6.2-stable_win64_console.exe --headless --path runtime --editor --import\nif errorlevel 1 goto failed\necho Setup complete. Run Run_Diablo_Survivors.bat to play.\npause\nexit /b 0\n:failed\necho Setup failed. See the error above.\npause\nexit /b 1\n',encoding="utf-8")
    (TARGET/"README.md").write_text('''# Diablo Survivors

Windows playable source package. Python 3.12 or newer (64-bit) must be installed and available as `python`.

1. Run **Setup.bat** once. Internet access is required to install the Python dependencies, Godot 4.6.2, and StormLib 9.40. Godot and StormLib downloads are checksum verified.
2. Run **Run_Diablo_Survivors.bat**.
3. Choose Diablo I or classic Diablo II and select your own installed game folder. Original graphics/audio are imported locally; the first import takes longer than subsequent launches.

Diablo II with or without Lord of Destruction is supported; Resurrected / Infernal Edition is unsupported. LoD enables seven class unlocks instead of five. Diablo I has three class unlocks.

Select a character, area and difficulty, then Play. Easy lasts 8 minutes, Hard 12, and Legendary 16. Earn gold through challenges and buy permanent upgrades. Movement: WASD/arrows; pause: Space/Esc; upgrades: 1–3; character sheet: C; mute: M.

Caches, game-selection settings and progress are created in `.local` beside this package. Keep that folder to retain progress. No existing saves, cached assets, game archives or original Diablo images/audio are included.

Tested source versions: Diablo I GOG English executable product version 1.0.9.2; classic Diablo II base 1.0.0.1 inspected/representative assets decoded; Diablo II LoD English 1.0.7.0 imported and played with all seven classes. Base-only mode was also tested with expansion archives excluded from the current installation.

The Python files are required for game selection and asset import. This is not a standalone EXE distribution. See LICENSE and THIRD_PARTY_NOTICES.md for licensing. Dependencies are installed by Setup rather than bundled here.
''',encoding="utf-8")
    print(f"Playable package: {TARGET} ({len(files)+3} files)")

if __name__=="__main__":main()
