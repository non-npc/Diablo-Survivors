import subprocess
import sys
import zipfile
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
TREES = (".github", "manager", "inspector", "adapters", "runtime", "demo_assets", "profiles", "catalogs", "schemas", "docs", "scripts", "tests")
FILES = ("Run_GameShift.bat", "Choose_Game.bat", "Run_Diablo2_Survival.bat", "Run_Treasure_Event_Demo.bat", "Run_Cow_Level_Demo.bat", "Run_Tristram_Survival.bat", "Run_Survival_Demo.bat", "Run_Synthetic_Survival.bat", "Run_Imported_Demo.bat", "Run_Manager.bat", "Run_Inspector.bat", "Run_Demo.bat", "README.md", "LICENSE", "THIRD_PARTY_NOTICES.md", "CONTRIBUTING.md", "requirements.txt", "requirements-dev.txt", "pyproject.toml")

def main():
    subprocess.run([sys.executable, str(ROOT / "scripts/validate_assets.py")], check=True)
    target = ROOT / "dist/diablo-survivors-source.zip"
    target.parent.mkdir(exist_ok=True)
    with zipfile.ZipFile(target, "w", zipfile.ZIP_DEFLATED) as archive:
        for tree in TREES:
            for path in sorted((ROOT / tree).rglob("*")):
                if path.is_file() and not any(part in {".godot", "__pycache__", ".pytest_cache"} for part in path.parts) and path.suffix not in {".pyc", ".import"}:
                    archive.write(path, Path("DiabloSurvivors") / path.relative_to(ROOT))
        for name in FILES:
            archive.write(ROOT / name, Path("DiabloSurvivors") / name)
    print(target)

if __name__ == "__main__":
    main()
