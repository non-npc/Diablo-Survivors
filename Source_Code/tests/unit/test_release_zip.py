import zipfile
import pytest
from scripts import build_windows_release as builder


def test_release_preserves_nested_runtime_zip(tmp_path, monkeypatch):
    monkeypatch.setattr(builder, 'ROOT', tmp_path)
    release=tmp_path/'release'
    internal=release/'_internal'
    internal.mkdir(parents=True)
    with zipfile.ZipFile(internal/'base_library.zip','w') as library:
        library.writestr('encodings/__init__.pyc',b'python bytecode fixture')
    (release/'old-release.zip').write_bytes(b'old distribution')
    (release/'.local').mkdir()
    (release/'.local/save.json').write_text('{}')
    with zipfile.ZipFile(builder.zip_release(release)) as result:
        assert 'Diablo Survivors/_internal/base_library.zip' in result.namelist()
        assert not any('old-release' in name or '.local' in name for name in result.namelist())


def test_release_rejects_missing_standard_library(tmp_path, monkeypatch):
    monkeypatch.setattr(builder, 'ROOT', tmp_path)
    release=tmp_path/'release'
    release.mkdir()
    with pytest.raises(ValueError,match='standard library'):
        builder.zip_release(release)
