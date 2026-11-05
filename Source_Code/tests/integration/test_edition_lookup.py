import hashlib
import pytest
from manager.services import catalog

def test_fingerprint_match_not_filename_guess(tmp_path, monkeypatch):
    data = b"synthetic archive, no proprietary content"
    (tmp_path / "base.mpq").write_bytes(data)
    profile = {"edition_id": "synthetic", "archives": [{"path": "base.mpq", "size_bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}], "verification": "verified", "notes": "synthetic test"}
    monkeypatch.setattr(catalog, "profiles", lambda: [profile])
    assert catalog.inspect_installation(tmp_path)["import_available"] is True
    (tmp_path / "base.mpq").write_bytes(b"x" * len(data))
    assert catalog.inspect_installation(tmp_path)["edition_id"] is None

def test_cancel_hashing(tmp_path, monkeypatch):
    (tmp_path / "base.mpq").write_bytes(b"synthetic")
    monkeypatch.setattr(catalog, "profiles", lambda: [{"archives": [{"path": "base.mpq", "size_bytes": 9, "sha256": "0" * 64}]}])
    with pytest.raises(catalog.InspectionCancelled):
        catalog.inspect_installation(tmp_path, cancelled=lambda: True)
