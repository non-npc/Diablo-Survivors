from pathlib import Path
import shutil
from scripts.sfx_release import omit_distribution_archives


def test_sfx_preserves_python_standard_library(tmp_path):
    source = tmp_path / 'build'
    (source / '_internal').mkdir(parents=True)
    (source / '_internal/base_library.zip').write_bytes(b'python runtime')
    (source / 'distribution.zip').write_bytes(b'distribution')
    (source / '.local').mkdir()
    (source / '.local/private.txt').write_text('private')
    target = tmp_path / 'payload'
    shutil.copytree(source, target, ignore=lambda folder, names: omit_distribution_archives(source, folder, names))
    assert (target / '_internal/base_library.zip').read_bytes() == b'python runtime'
    assert not (target / 'distribution.zip').exists()
    assert not (target / '.local').exists()
