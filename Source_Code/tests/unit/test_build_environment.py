from scripts.build_windows_release import build_environment

def test_release_build_uses_clean_native_library_path(monkeypatch):
    monkeypatch.setenv('PATH',r'X:\unrelated\icu;X:\unrelated\ucrt')
    monkeypatch.setenv('PYTHONPATH',r'X:\other-python')
    monkeypatch.setenv('QT_PLUGIN_PATH',r'X:\other-qt')
    env = build_environment()
    assert 'unrelated' not in env['PATH']
    assert 'PYTHONPATH' not in env
    assert 'QT_PLUGIN_PATH' not in env
    assert 'system32' in env['PATH'].lower()
