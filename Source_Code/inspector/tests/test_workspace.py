import hashlib
import struct
from pathlib import Path
import pytest
from adapters.base.mpq import CRYPT, MASK, ClassicMPQ, StormArchive, name_hash, safe_resource_path
from inspector.services import workspace
from inspector.services.workspace import build_documents, save_documents, scan_installation, import_resources, Cancelled

def encrypt_table(data, key):
    seed = 0xEEEEEEEE
    out = bytearray()
    for plain, in struct.iter_unpack("<I", data):
        seed = (seed + CRYPT[0x400 + (key & 255)]) & MASK
        out.extend(struct.pack("<I", plain ^ ((key + seed) & MASK)))
        key = (((~key << 21) + 0x11111111) | (key >> 11)) & MASK
        seed = (plain + seed + (seed << 5) + 3) & MASK
    return bytes(out)

def synthetic_mpq(path, name="synthetic/test.pal", data=bytes(range(256)) * 3):
    hashes = [(MASK, MASK, 0xffff, 0xffff, MASK)] * 8
    index = name_hash(name, 0) % 8
    hashes[index] = (name_hash(name, 1), name_hash(name, 2), 0, 0, 0)
    hash_offset = 32 + len(data)
    block_offset = hash_offset + 128
    size = block_offset + 16
    header = struct.pack("<4sIIHHIIII", b"MPQ\x1a", 32, size, 0, 3, hash_offset, block_offset, 8, 1)
    hash_bytes = b"".join(struct.pack("<IIHHI", *h) for h in hashes)
    block_bytes = struct.pack("<IIII", 32, len(data), len(data), 0x80000000)
    path.write_bytes(header + data + encrypt_table(hash_bytes, name_hash("(hash table)", 3)) + encrypt_table(block_bytes, name_hash("(block table)", 3)))
    return data

def test_synthetic_mpq_lookup_and_missing_name(tmp_path):
    source = tmp_path / "test.mpq"
    data = synthetic_mpq(source)
    archive = ClassicMPQ(source)
    assert archive.lookup("SYNTHETIC\\TEST.PAL")["decoded_bytes"] == len(data)
    assert archive.lookup("missing") is None
    assert archive.rows(["synthetic/test.pal"])[0]["source_path"] == "synthetic/test.pal"

def test_reject_out_of_bounds_table(tmp_path):
    source = tmp_path / "test.mpq"
    synthetic_mpq(source)
    data = bytearray(source.read_bytes())
    struct.pack_into("<I", data, 16, 0xFFFFFF00)
    source.write_bytes(data)
    with pytest.raises(ValueError, match="outside"):
        ClassicMPQ(source)

@pytest.mark.parametrize("name", ["../x", "a/../x", "C:/x", "/x", "a//x", "a\\..\\x", "a:stream"])
def test_archive_path_safety(name):
    with pytest.raises(ValueError): safe_resource_path(name)

def test_scan_reuses_hash_and_exports_draft(tmp_path, monkeypatch):
    game = tmp_path / "game"
    game.mkdir()
    synthetic_mpq(game / "base.mpq")
    work = tmp_path / "workspace"
    # The optional reader is unnecessary for metadata; emulate absent listfile.
    monkeypatch.setattr(workspace, "StormArchive", lambda p: (_ for _ in ()).throw(RuntimeError("not installed")))
    report = scan_installation(game, work, ["synthetic/test.pal"])
    assert len(report["archives"][0]["assets"]) == 1
    monkeypatch.setattr(workspace, "digest_file", lambda *a, **k: (_ for _ in ()).throw(AssertionError("must reuse fingerprint")))
    again = scan_installation(game, work, ["synthetic/test.pal"])
    assert again["archives"][0]["sha256"] == report["archives"][0]["sha256"]
    profile, catalog = build_documents(report, "test-edition", "test", "Synthetic", "en-US", "test", ["base.mpq"])
    assert profile["verification"] == "inspected"
    destination = Path(save_documents(work / "drafts", profile, catalog))
    assert (destination / "profile.json").is_file()
    assert len(catalog["assets"]) == 1

def test_cancel_scan_preserves_previous_index(tmp_path):
    game = tmp_path / "game"
    game.mkdir()
    synthetic_mpq(game / "base.mpq")
    work = tmp_path / "work"
    work.mkdir()
    old = work / "last_inspection.json"
    old.write_text('{"previous": true}')
    with pytest.raises(Cancelled): scan_installation(game, work, cancelled=lambda: True)
    assert old.read_text() == '{"previous": true}'

def test_import_staging_cancel_and_success(tmp_path, monkeypatch):
    game = tmp_path / "game"
    game.mkdir()
    source = game / "base.mpq"
    payload = synthetic_mpq(source)
    row = ClassicMPQ(source).rows(["synthetic/test.pal"])[0]
    report = {"installation": str(game), "archives": [{"relative_path": "base.mpq", "path": str(source), "size_bytes": source.stat().st_size, "mtime_ns": source.stat().st_mtime_ns, "sha256": hashlib.sha256(source.read_bytes()).hexdigest()}]}
    class Reader:
        def __init__(self, path): pass
        def read(self, name): return payload
        def close(self): pass
    monkeypatch.setattr(workspace, "StormArchive", Reader)
    work = tmp_path / "cache"
    with pytest.raises(Cancelled): import_resources(report, [("base.mpq", row)], work, cancelled=lambda: True)
    assert not list((work / "imports").glob(".staging-*"))
    result = import_resources(report, [("base.mpq", row)], work)
    assert Path(result["output_dir"], result["assets"][0]["raw_path"]).read_bytes() == payload
    assert Path(result["output_dir"], result["assets"][0]["preview_path"]).is_file()
    assert source.is_file()
    monkeypatch.setattr(workspace, "StormArchive", lambda p: (_ for _ in ()).throw(AssertionError("repeat import must reuse cache")))
    again = import_resources(report, [("base.mpq", row)], work)
    assert again["reused"] is True
    assert again["output_dir"] == result["output_dir"]

def test_working_cache_cannot_be_source_folder(tmp_path):
    report = {"installation": str(tmp_path), "archives": []}
    with pytest.raises(ValueError, match="outside"):
        import_resources(report, [("base", {"decoded_bytes": 0})], tmp_path / "inside")


def test_version_metadata_is_not_required_for_synthetic_archives(tmp_path):
    from inspector.services.metadata import installation_metadata
    assert installation_metadata(tmp_path) == {"executables": [], "distribution_metadata": []}
