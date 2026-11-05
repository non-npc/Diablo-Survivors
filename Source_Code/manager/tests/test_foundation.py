import json
import pytest
from jsonschema import ValidationError
from manager.db.store import Store
from manager.services.catalog import inspect_installation, validate_document, profiles
from manager.services.paths import ROOT
from manager.services.runtime import demo_arguments, find_godot

def test_database_roundtrip_and_reopen(tmp_path):
    store = Store(tmp_path)
    store.set("godot_path", "unicode path/世界/godot")
    store.save_installation({"path": "C:/Games/世界", "status": "Research baseline"})
    store.close()
    reopened = Store(tmp_path)
    assert reopened.get("godot_path") == "unicode path/世界/godot"
    assert reopened.installations()[0]["status"] == "Research baseline"
    reopened.close()

def test_reject_future_database_without_downgrading(tmp_path):
    store = Store(tmp_path)
    store.connection.execute("PRAGMA user_version=99")
    store.close()
    with pytest.raises(RuntimeError, match="newer"):
        Store(tmp_path)

def test_unknown_edition_never_claims_support(tmp_path):
    result = inspect_installation(tmp_path)
    assert result["edition_id"] is None
    assert result["status"] == "Unknown edition"

def test_profile_keeps_research_separate_from_verified():
    baseline = profiles()[0]
    assert baseline["verification"] == "inspected"
    assert baseline["distribution"] == "GOG"
    assert baseline["executable_product_version"] == "1.0.9.2"

@pytest.mark.parametrize("path", ["../escape", "foo/../escape", "C:/absolute", "/absolute", "..\\escape"])
def test_reject_unsafe_catalog_path(path):
    document = {"schema_version": 1, "catalog_id": "test", "edition_id": "test", "assets": [{"id": "bad", "archive": "base", "source_path": path, "type": "sprite", "verified": False}]}
    with pytest.raises(ValidationError):
        validate_document(document, "asset_catalog.schema.json")

def test_missing_godot_configuration_is_actionable(tmp_path):
    with pytest.raises(FileNotFoundError, match="Settings"):
        find_godot(str(tmp_path / "missing.exe"))

def test_runtime_arguments_preserve_path_boundaries():
    args = demo_arguments(True)
    assert args[0] == "--headless"
    assert args[args.index("--manifest") + 1] == str(ROOT / "demo_assets/demo_manifest.json")

def test_reject_manifest_missing_actors():
    manifest = json.loads((ROOT / "demo_assets/demo_manifest.json").read_text())
    manifest["actors"] = []
    with pytest.raises(ValidationError):
        validate_document(manifest, "game_manifest.schema.json")
