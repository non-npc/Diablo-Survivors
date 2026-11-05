import json
import os
import sqlite3
import time
from pathlib import Path
import pytest
from inspector.services import workspace, preparation
from inspector.services.preparation import prepare_installation
from inspector.tests.test_workspace import synthetic_mpq

@pytest.fixture
def game(tmp_path, monkeypatch):
    folder = tmp_path / "game"
    folder.mkdir()
    payload = synthetic_mpq(folder / "base.mpq")
    class Reader:
        def __init__(self, path): pass
        def read(self, name, *args):
            if name == "(listfile)": raise FileNotFoundError(name)
            return payload
        def close(self): pass
        def __enter__(self): return self
        def __exit__(self, *args): self.close()
    monkeypatch.setattr(workspace, "StormArchive", Reader)
    return folder

def test_automatic_preparation_database_and_metadata(game, tmp_path):
    result = prepare_installation(game, tmp_path / "workspace", ["synthetic/test.pal"])
    with sqlite3.connect(result["database_path"]) as db:
        assert db.execute("SELECT count(*) FROM assets").fetchone()[0] == 1
        name, status, raw = db.execute("SELECT source_path,status,raw_path FROM assets").fetchone()
        assert db.execute("SELECT format,confidence FROM assets").fetchone() == ("RGB256", "structure")
        assert name.replace("\\", "/") == "synthetic/test.pal"
        assert status == "palette swatch PNG"
        assert Path(raw).is_file()
    assert Path(result["profile_path"]).is_file()
    assert Path(result["catalog_path"]).is_file()
    assert result["profile"]["verification"] == "inspected"
    assert result["ready_for_gameplay"] is False

def test_unnamed_blocks_are_still_indexed(game, tmp_path):
    result = prepare_installation(game, tmp_path / "workspace")
    with sqlite3.connect(result["database_path"]) as db:
        assert db.execute("SELECT status FROM assets").fetchone()[0] == "unnamed"
    assert result["named_count"] == 0
    assert result["imported_count"] == 0

def test_reuses_same_database_and_imports(game, tmp_path, monkeypatch):
    work = tmp_path / "workspace"
    first = prepare_installation(game, work, ["synthetic/test.pal"])
    monkeypatch.setattr(preparation, "write_database", lambda *a, **k: (_ for _ in ()).throw(AssertionError("database must be reused")))
    second = prepare_installation(game, work, ["synthetic/test.pal"])
    assert second["reused"] is True
    assert second["database_path"] == first["database_path"]
    assert second["imported"]["reused"] is True

def test_cancel_before_activation_preserves_previous_database(game, tmp_path, monkeypatch):
    work = tmp_path / "workspace"
    first = prepare_installation(game, work, ["synthetic/test.pal"])
    active = Path(first["database_path"]).parents[2] / "active.json"
    previous = active.read_bytes()
    original = preparation.write_database
    def cancel_during_database(*args, **kwargs):
        raise workspace.Cancelled()
    # A new candidate catalog changes the generation identity without new payloads.
    synthetic_mpq(game / "second.mpq", name="other/file.dat", data=b"synthetic second resource")
    monkeypatch.setattr(preparation, "write_database", cancel_during_database)
    with pytest.raises(workspace.Cancelled):
        prepare_installation(game, work, ["synthetic/test.pal"])
    assert active.read_bytes() == previous
    assert Path(first["database_path"]).is_file()
    assert not list(active.parent.glob("generations/.staging-*"))

def test_typing_directory_starts_preparation_automatically(game, tmp_path):
    os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
    from PyQt6.QtWidgets import QApplication
    from manager.ui.fonts import configure_fonts
    from inspector.ui.window import InspectorWindow
    app = QApplication.instance() or QApplication([])
    configure_fonts(app)
    window = InspectorWindow(tmp_path / "gui-workspace")
    window.extra_names.add("synthetic/test.pal")
    window.folder.setText(str(game))
    deadline = time.monotonic() + 10
    try:
        while window.prepared_folder is None and time.monotonic() < deadline:
            app.processEvents()
            time.sleep(0.01)
        assert window.prepared_folder == str(game.resolve())
        assert (tmp_path / "gui-workspace/last_preparation.json").is_file()
        assert "Database ready" in window.status.text()
        window.assets.selectRow(0)
        window.preview_selected()
        assert window.preview_sheet is not None and not window.preview_sheet.isNull()
        assert "RGB256" in window.asset_details.toPlainText()
        window.type_filter.setCurrentText("audio")
        assert window.assets.rowCount() == 0
        window.type_filter.setCurrentText("palette")
        assert window.assets.rowCount() == 1
        deadline = time.monotonic() + 3
        while window.job.isRunning() and time.monotonic() < deadline:
            app.processEvents()
        app.processEvents()
    finally:
        if window.job and window.job.isRunning():
            window.job.requestInterruption()
            window.job.wait()
        window.close()


def test_catalog_does_not_export_original_text_content(tmp_path, monkeypatch):
    folder=tmp_path/"private-game"
    folder.mkdir()
    payload=b"private original resource text"
    synthetic_mpq(folder/"base.mpq",name="odd.pal",data=payload)
    class Reader:
        def __init__(self,path): pass
        def read(self,name,*args):
            if name=="(listfile)": raise FileNotFoundError()
            return payload
        def close(self): pass
        def __enter__(self): return self
        def __exit__(self,*args): pass
    monkeypatch.setattr(workspace,"StormArchive",Reader)
    result=prepare_installation(folder,tmp_path/"work",["odd.pal"])
    assert "text_preview" not in result["catalog"]["assets"][0]["identification"]
    with sqlite3.connect(result["database_path"]) as db:
        metadata=json.loads(db.execute("SELECT metadata_json FROM assets").fetchone()[0])
        assert metadata["text_preview"]==payload.decode()
