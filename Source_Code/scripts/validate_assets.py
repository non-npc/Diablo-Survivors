import json
import sys
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from manager.services.catalog import validate_document, profiles

def main():
    from jsonschema import Draft202012Validator
    for path in (ROOT / "schemas").glob("*.json"):
        Draft202012Validator.check_schema(json.loads(path.read_text()))
    upgrade_catalog=json.loads((ROOT/"runtime/resources/upgrades.json").read_text())
    validate_document(upgrade_catalog,"run_upgrade_catalog.schema.json")
    ids=[entry["id"] for entry in upgrade_catalog]
    if len(ids)!=len(set(ids)):raise SystemExit("Duplicate run upgrade IDs")
    if any(entry.get("requires") not in ids for entry in upgrade_catalog if entry.get("requires")):raise SystemExit("Unknown upgrade prerequisite")
    if json.loads((ROOT/"runtime/resources/survival_demo.json").read_text())["configuration"]["upgrades"]!=upgrade_catalog:raise SystemExit("Synthetic upgrade catalog differs")
    profiles()
    validate_document(json.loads((ROOT / "demo_assets/demo_manifest.json").read_text()), "game_manifest.schema.json")
    for path in (ROOT / "catalogs").glob("*.json"):
        validate_document(json.loads(path.read_text()), "asset_catalog.schema.json")
    if (ROOT / "demo_assets/demo_manifest.json").read_bytes() != (ROOT / "runtime/resources/demo_manifest.json").read_bytes():
        raise SystemExit("Demo manifests differ")
    prohibited = {".mpq", ".cel", ".cl2", ".dcc", ".dc6", ".dt1", ".ds1", ".dll", ".exe"}
    for tree in ("manager", "inspector", "runtime", "adapters", "demo_assets", "profiles", "catalogs", "tests"):
        for path in (ROOT / tree).rglob("*"):
            if ".godot" in path.parts or "__pycache__" in path.parts:
                continue
            if path.is_file() and path.suffix.lower() in prohibited:
                raise SystemExit(f"Disallowed source payload: {path}")
    print("Schemas and metadata validated; no prohibited source payload extensions. This guard is not a content/license audit.")

if __name__ == "__main__":
    main()
