"""First-run source picker and cached game launch, without requiring both games."""
import sys,json,re,traceback
from pathlib import Path
from PyQt6.QtCore import QThread,pyqtSignal,QProcess,QTimer
from PyQt6.QtWidgets import QApplication,QDialog,QVBoxLayout,QHBoxLayout,QLabel,QButtonGroup,QRadioButton,QLineEdit,QPushButton,QFileDialog,QProgressBar
from manager.services.game_sources import GAMES,settings,save_choice,prepare_source
from manager.services.runtime import find_godot
from manager.services.paths import ROOT
from manager.ui.window import STYLE
from manager.version import APP_TITLE
from inspector.services.workspace import atomic_json
class Preparation(QThread):
    message=pyqtSignal(str);ready=pyqtSignal(str);failed=pyqtSignal(str)
    def __init__(self,game,folder,parent=None):super().__init__(parent);self.game=game;self.folder=folder
    def run(self):
        try:self.ready.emit(str(prepare_source(self.game,self.folder,self.message.emit)))
        except Exception as error:self.failed.emit(str(error))
class GameSelector(QDialog):
    def __init__(self,configure=False):
        super().__init__();self.worker=None;self.runtime=QProcess(self);self.runtime.setProcessChannelMode(QProcess.ProcessChannelMode.MergedChannels);self.runtime_output=""
        self.runtime.readyReadStandardOutput.connect(self.read_runtime);self.runtime.finished.connect(self.finished_game);self.runtime.errorOccurred.connect(lambda error:self.fail(self.runtime.errorString()))
        self.runtime.started.connect(self.runtime_started)
        self.setWindowTitle(APP_TITLE+" — Choose your game");self.resize(620,420);self.setStyleSheet(STYLE)
        layout=QVBoxLayout(self);layout.setContentsMargins(28,28,28,28);layout.setSpacing(18)
        title=QLabel("Choose your game's graphics and audio");title.setObjectName("brand");title.setWordWrap(True);layout.addWidget(title)
        description=QLabel("Use the original assets from a game you have installed. You only need one of these games, and can change your choice from the main menu.");description.setWordWrap(True);layout.addWidget(description)
        self.game=QButtonGroup(self);self.game_buttons={};choices=QVBoxLayout()
        for key,title in GAMES.items():
            button=QRadioButton(title);button.setProperty("game_id",key);self.game.addButton(button);self.game_buttons[key]=button;choices.addWidget(button)
        self.game_buttons["diablo1"].setChecked(True)
        layout.addLayout(choices);self.path=QLineEdit();self.path.setPlaceholderText("Choose the game installation folder")
        row=QHBoxLayout();row.addWidget(self.path);self.browse=QPushButton("Browse…");self.browse.clicked.connect(self.choose_folder);row.addWidget(self.browse);layout.addLayout(row)
        self.status=QLabel("Classic Diablo II with or without Lord of Destruction is supported. Resurrected / Infernal Edition is not supported.");self.status.setWordWrap(True);layout.addWidget(self.status)
        self.progress=QProgressBar();self.progress.setRange(0,0);self.progress.hide();layout.addWidget(self.progress)
        self.play=QPushButton("Import assets and launch game when ready");self.play.setObjectName("primary");self.play.clicked.connect(self.prepare);layout.addWidget(self.play)
        self.game.buttonClicked.connect(self.changed_game)
        self.path.textChanged.connect(self.source_hint)
        saved=settings();active=saved.get("active_game")
        if active in self.game_buttons:self.game_buttons[active].setChecked(True)
        self.changed_game()
        self.show()
        if active in GAMES and self.path.text() and not configure:QTimer.singleShot(0,self.prepare)
    def selected_source(self):return self.game.checkedButton().property("game_id")
    def changed_game(self,*args):
        key=self.selected_source();known=settings().get("games",{}).get(key,{}).get("folder","")
        self.path.setText(known)
    def source_hint(self):
        if self.selected_source()!="diablo1":
            folder=Path(self.path.text());lod=(folder/"d2exp.mpq").is_file()
            hint=("Lord of Destruction — seven playable class unlocks." if lod else "Select an installation containing d2exp.mpq for Lord of Destruction.") if self.selected_source()=="diablo2_lod" else "Classic Diablo II — five playable class unlocks. Expansion assets will be excluded."
            self.status.setText(hint+" Resurrected / Infernal Edition is not supported.")
        else:self.status.setText("Diablo I — Warrior, Rogue and Sorcerer. Select the folder containing DIABDAT.MPQ.")
    def choose_folder(self):
        path=QFileDialog.getExistingDirectory(self,"Choose "+GAMES[self.selected_source()]+" folder",self.path.text())
        if path:self.path.setText(path)
    def prepare(self):
        if self.worker is not None and self.worker.isRunning():return
        if not self.path.text().strip():self.fail("Choose the game installation folder first.");return
        self.selected_game=self.selected_source();self.selected_folder=self.path.text().strip()
        self.set_busy(True);self.status.setText("Preparing your local assets…")
        self.worker=Preparation(self.selected_game,self.selected_folder,self);self.worker.message.connect(self.show_progress);self.worker.ready.connect(self.launch);self.worker.failed.connect(self.fail);self.worker.start()
    def show_progress(self,message):
        match=re.match(r"\[(\d+)/(\d+)\]\s*(.*)",message)
        if match:
            current,total=int(match[1]),int(match[2]);self.progress.setRange(0,total);self.progress.setValue(current-1)
            self.progress.setFormat(f"Asset {current} / {total} — {total-current} queued after this")
            self.status.setText(match[3])
        else:
            self.status.setText(message);self.progress.setRange(0,0)
    def set_busy(self,busy):
        for control in [*self.game_buttons.values(),self.path,self.browse,self.play]:control.setEnabled(not busy)
        self.progress.setVisible(busy)
    def launch(self,manifest):
        try:
            manifest=str(Path(manifest).resolve())
            if not Path(manifest).is_file():raise FileNotFoundError("Prepared asset manifest is missing: "+manifest)
            binary=find_godot();save_choice(self.selected_game,self.selected_folder)
            atomic_json(ROOT/".local/launcher/active_manifest.json",{"game":self.selected_game,"manifest_path":manifest})
            logs=ROOT/".local/logs";logs.mkdir(parents=True,exist_ok=True)
            self.runtime_output="";self.runtime.setWorkingDirectory(str(ROOT))
            arguments=["--log-file",str(logs/"game.log"),"--","--survival-manifest",manifest] if getattr(sys,"frozen",False) else ["--path",str(ROOT/"runtime"),"--log-file",str(logs/"game.log"),"res://scenes/survival.tscn","--","--survival-manifest",manifest]
            self.log_message(json.dumps({"executable":binary,"arguments":arguments,"working_directory":str(ROOT)},ensure_ascii=False))
            self.status.setText("Assets ready. Starting the game…")
            self.runtime.start(binary,arguments)
        except Exception as error:
            self.log_message(traceback.format_exc());self.fail(str(error))
    def runtime_started(self):self.hide()
    def log_message(self,message):
        try:
            path=ROOT/".local/logs/launcher.log";path.parent.mkdir(parents=True,exist_ok=True)
            with path.open("a",encoding="utf-8") as stream:stream.write(message+"\n")
        except OSError:pass
    def read_runtime(self):
        output=bytes(self.runtime.readAllStandardOutput()).decode("utf-8",errors="replace");self.runtime_output=(self.runtime_output+output)[-10000:]
        if sys.stdout is not None:print(output,end="",flush=True)
    def finished_game(self,code,status):
        if code==20:self.set_busy(False);self.status.setText("Choose which installed game to use.");self.show()
        elif code!=0:self.fail("The game could not start. "+self.runtime_output[-1200:])
        else:QApplication.instance().quit()
    def fail(self,message):
        self.log_message(message);self.set_busy(False)
        self.status.setText(message+"\nLaunch diagnostics: "+str(ROOT/".local/logs"));self.show()
    def closeEvent(self,event):
        if self.worker is not None and self.worker.isRunning():event.ignore();return
        QApplication.instance().quit();event.accept()
def main(configure=False):
    app=QApplication(sys.argv[:1]);app.setQuitOnLastWindowClosed(False)
    from manager.ui.fonts import configure_fonts
    configure_fonts(app);window=GameSelector(configure);return app.exec()
