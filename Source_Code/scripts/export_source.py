"""Export a clean, independently buildable contributor source snapshot."""
from pathlib import Path
import hashlib
import json
import shutil

ROOT = Path(__file__).resolve().parents[1]
TREES = (".github", "manager", "inspector", "adapters", "runtime", "demo_assets", "profiles", "catalogs", "schemas", "docs", "scripts", "tests")
FILES = (".gitignore", "LICENSE", "THIRD_PARTY_NOTICES.md", "CONTRIBUTING.md", "pyproject.toml", "requirements.txt", "requirements-dev.txt", "requirements-build.txt", "Build_Windows_Release.bat")
SKIP = {".godot", "__pycache__", ".pytest_cache", ".git", ".local", ".tools", ".venv"}
INTERNAL_DOCS = {"STATUS.md", "README-development-history.md"}
PROHIBITED = {".pyc", ".pyo", ".import", ".mpq", ".cel", ".cl2", ".dcc", ".dc6", ".dt1", ".ds1", ".exe", ".dll", ".pck", ".ogg", ".wav", ".mp4", ".zip", ".rar"}

def main():
    target = ROOT / "Source_Code"
    if target.exists():
        raise SystemExit("Source_Code already exists; move or rename it before exporting. Existing files were preserved.")
    paths = [ROOT / name for name in FILES]
    paths += sorted(ROOT.glob("Run_*.bat")) + [ROOT / "Choose_Game.bat"]
    for name in TREES:
        for path in sorted((ROOT / name).rglob("*")):
            relative = path.relative_to(ROOT)
            if path.is_file() and not any(part in SKIP for part in relative.parts) and path.name not in INTERNAL_DOCS and not path.name.startswith("--") and path.suffix.lower() not in PROHIBITED:
                paths.append(path)
    for path in sorted(set(paths)):
        destination = target / path.relative_to(ROOT)
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, destination)
    shutil.copy2(ROOT / "README.md", target / "PROJECT_OVERVIEW.md")
    shutil.copy2(ROOT / "docs/source_build.md", target / "readme.md")
    (target / "extras").mkdir()
    (target / "extras/README.md").write_text("# Optional audio\n\nThird-party goblin and hit audio is omitted from this clean source copy. The client runs without it. Only add audio you have permission to use and redistribute, and preserve its license notices.\n", encoding="utf-8")
    hashes = {p.relative_to(target).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(target.rglob("*")) if p.is_file()}
    (target / "SOURCE_MANIFEST.json").write_text(json.dumps({"files": hashes, "excluded": "Imported game data, optional third-party audio, saves, caches, installed tools, environments and compiled releases."}, indent=2) + "\n", encoding="utf-8")
    print(f"Exported {len(hashes)} clean source files to {target}")

if __name__ == "__main__":
    main()
