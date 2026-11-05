import pytest
from manager.services.game_sources import settings,save_choice
from adapters.diablo2.importer import detect,BASE_CLASSES,EXPANSION_CLASSES

def test_choices_keep_both_game_folders(tmp_path):
    path=tmp_path/'settings.json';save_choice('diablo1',tmp_path/'first',path);save_choice('diablo2',tmp_path/'second',path)
    value=settings(path)
    assert value['active_game']=='diablo2' and set(value['games'])=={'diablo1','diablo2'}

def test_reject_resurrected_and_missing_archives(tmp_path):
    (tmp_path/'D2R.exe').write_bytes(b'')
    with pytest.raises(ValueError,match='Resurrected'):detect(tmp_path)
    (tmp_path/'D2R.exe').unlink()
    with pytest.raises(ValueError,match='missing'):detect(tmp_path)
    assert len(BASE_CLASSES)==5 and set(EXPANSION_CLASSES)=={'assassin','druid'}


def test_source_picker_prepares_only_selected_game(tmp_path,monkeypatch):
    import os
    os.environ.setdefault('QT_QPA_PLATFORM','offscreen')
    from PyQt6.QtWidgets import QApplication
    from PyQt6.QtCore import QEventLoop,QTimer
    import manager.ui.game_selector as selector
    app=QApplication.instance() or QApplication([])
    monkeypatch.setattr(selector,'settings',lambda:{})
    requested=[]
    def prepared(game,folder,progress):
        requested.append((game,folder));return tmp_path/'manifest.json'
    monkeypatch.setattr(selector,'prepare_source',prepared)
    window=selector.GameSelector(configure=True)
    assert len(window.game_buttons)==3
    window.game_buttons['diablo2'].click();window.path.setText(str(tmp_path))
    assert window.selected_source()=='diablo2'
    window.show_progress('[42/309] Bestiary: Ghost')
    assert window.progress.maximum()==309 and window.progress.value()==41
    assert '267 queued after this' in window.progress.format()
    assert window.status.text()=='Bestiary: Ghost'
    window.show_progress('Caching audio')
    assert window.progress.maximum()==0
    loop=QEventLoop();results=[]
    def launched(path):results.append(path);loop.quit()
    window.launch=launched
    QTimer.singleShot(5000,loop.quit)
    window.prepare();loop.exec();window.worker.wait(5000)
    assert requested==[('diablo2',str(tmp_path))] and results==[str(tmp_path/'manifest.json')]
    window.hide();window.deleteLater();app.processEvents()


def test_frozen_launch_passes_manifest_and_waits_for_start(tmp_path,monkeypatch):
    import os,sys,json
    os.environ.setdefault('QT_QPA_PLATFORM','offscreen')
    from PyQt6.QtWidgets import QApplication
    import manager.ui.game_selector as selector
    app=QApplication.instance() or QApplication([])
    root=tmp_path/'portable game é';root.mkdir()
    manifest=root/'cached assets/survival.json';manifest.parent.mkdir();manifest.write_text('{}')
    monkeypatch.setattr(selector,'ROOT',root)
    monkeypatch.setattr(selector,'settings',lambda:{})
    monkeypatch.setattr(selector,'save_choice',lambda *args:None)
    monkeypatch.setattr(selector,'find_godot',lambda:str(root/'game/Game.exe'))
    monkeypatch.setattr(sys,'frozen',True,raising=False)
    class Process:
        def setWorkingDirectory(self,path):self.directory=path
        def start(self,binary,arguments):self.binary=binary;self.arguments=arguments
    window=selector.GameSelector(configure=True);window.runtime=Process()
    window.selected_game='diablo2_lod';window.selected_folder=str(root)
    window.launch(str(manifest))
    assert window.isVisible(), 'Keep the launcher visible until process startup succeeds'
    assert window.runtime.arguments[-2:]==['--survival-manifest',str(manifest.resolve())]
    assert '--path' not in window.runtime.arguments and '--log-file' in window.runtime.arguments
    assert json.loads((root/'.local/launcher/active_manifest.json').read_text())['manifest_path']==str(manifest.resolve())
    window.runtime_started();assert not window.isVisible()
    window.deleteLater();app.processEvents()
