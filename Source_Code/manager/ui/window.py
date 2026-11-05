from PyQt6.QtCore import QProcess
from PyQt6.QtWidgets import (QMainWindow, QWidget, QHBoxLayout, QVBoxLayout, QLabel, QPushButton, QListWidget, QStackedWidget, QFrame, QLineEdit, QFileDialog, QProgressBar, QPlainTextEdit)
from manager.services.runtime import find_godot, demo_arguments
from manager.services.catalog import profiles, validate_document
from manager.services.paths import ROOT
from manager.workers.inspection import InspectionWorker

STYLE = """
QWidget { background: #10151d; color: #dde6ee; font-family: 'Segoe UI'; font-size: 14px; }
QMainWindow { background: #10151d; }
QLabel#brand { font-size: 27px; font-weight: 700; color: #f7f9fc; }
QLabel#heading { font-size: 30px; font-weight: 700; }
QLabel#muted { color: #8f9dac; }
QLabel#eyebrow { color: #64d4b1; font-weight: 700; }
QFrame#card { background: #18212c; border: 1px solid #2a3746; border-radius: 12px; }
QFrame#card QLabel { background: transparent; }
QPushButton { background: #243243; border: 1px solid #34485b; border-radius: 7px; padding: 11px 18px; font-weight: 600; }
QPushButton:hover { background: #30435a; }
QPushButton:disabled { color: #617080; background: #19232e; }
QPushButton#primary { background: #55d6a8; color: #092219; border: 0; }
QPushButton#primary:hover { background: #79e5bd; }
QListWidget { background: #10151d; border: 0; padding: 6px; }
QListWidget::item { padding: 15px 12px; border-radius: 7px; margin: 3px 0; }
QListWidget::item:selected { background: #243243; color: #73e6bc; }
QLineEdit, QPlainTextEdit { background: #0c1118; border: 1px solid #304052; border-radius: 7px; padding: 10px; }
QProgressBar { border: 1px solid #304052; border-radius: 5px; text-align: center; }
QProgressBar::chunk { background: #55d6a8; }
"""

class MainWindow(QMainWindow):
    def __init__(self, store):
        super().__init__()
        self.store = store
        self.worker = None
        self.runtime_output = ""
        self.preparation = QProcess(self)
        self.preparation.setProcessChannelMode(QProcess.ProcessChannelMode.MergedChannels)
        self.preparation.finished.connect(self.prepared)
        self.preparation.errorOccurred.connect(lambda error: self.preparation_failed(self.preparation.errorString()))
        self.runtime = QProcess(self)
        self.runtime.setProcessChannelMode(QProcess.ProcessChannelMode.MergedChannels)
        self.runtime.readyReadStandardOutput.connect(self.read_runtime)
        self.runtime.finished.connect(self.runtime_finished)
        self.runtime.errorOccurred.connect(self.runtime_error)
        self.setWindowTitle("GameShift — Library")
        self.resize(1160, 780)
        self.setMinimumSize(900, 650)
        self.setStyleSheet(STYLE)
        central = QWidget()
        self.setCentralWidget(central)
        outer = QHBoxLayout(central)
        outer.setContentsMargins(26, 28, 28, 24)
        outer.setSpacing(30)
        sidebar = QVBoxLayout()
        sidebar.addWidget(self.label("GameShift", "brand"))
        sidebar.addWidget(self.label("YOUR GAMES. NEW SURVIVAL.", "muted"))
        self.nav = QListWidget()
        self.nav.setFixedWidth(205)
        self.nav.addItems(["Library", "Import Game", "Campaigns", "Asset Browser", "Settings"])
        sidebar.addWidget(self.nav)
        sidebar.addWidget(self.label("M0 / FOUNDATION\nLocal assets • Offline play", "muted"))
        outer.addLayout(sidebar)
        self.pages = QStackedWidget()
        outer.addWidget(self.pages, 1)
        self.pages.addWidget(self.library_page())
        self.pages.addWidget(self.import_page())
        self.pages.addWidget(self.placeholder_page("Campaigns", "Original survival campaigns", "The synthetic demo is available from Library. Waves, upgrades and campaign editing are the next milestone."))
        self.pages.addWidget(self.placeholder_page("Asset Browser", "Your assets, with provenance", "Imported asset previews and mapping controls will become available after the importer is implemented."))
        self.pages.addWidget(self.settings_page())
        self.nav.currentRowChanged.connect(self.pages.setCurrentIndex)
        self.nav.setCurrentRow(0)
        self.refresh_library()

    def label(self, text, name=""):
        result = QLabel(text)
        result.setWordWrap(True)
        if name:
            result.setObjectName(name)
        return result

    def page(self, heading, description):
        page = QWidget()
        layout = QVBoxLayout(page)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(18)
        layout.addWidget(self.label(heading, "heading"))
        layout.addWidget(self.label(description, "muted"))
        return page, layout

    def library_page(self):
        page, layout = self.page("Your library", "Choose a world. Build a survival run.")
        card = QFrame()
        card.setObjectName("card")
        body = QVBoxLayout(card)
        body.setContentsMargins(25, 25, 25, 25)
        body.addWidget(self.label("READY TO PLAY  /  ORIGINAL ASSETS", "eyebrow"))
        body.addWidget(self.label("The proving grounds", "heading"))
        body.addWidget(self.label("Explore a bounded 2D arena with an original hero and orbiting lights.\nMove with WASD or arrow keys. Escape closes the demo.", "muted"))
        self.play = QPushButton("Play demo  →")
        self.play.setObjectName("primary")
        self.play.clicked.connect(lambda: self.launch_demo())
        body.addWidget(self.play)
        layout.addWidget(card)
        self.installed = self.label("", "muted")
        layout.addWidget(self.installed)
        layout.addWidget(self.label("Runtime log", "eyebrow"))
        self.log = QPlainTextEdit()
        self.log.setReadOnly(True)
        self.log.setMaximumBlockCount(1000)
        layout.addWidget(self.log, 1)
        return page

    def import_page(self):
        page, layout = self.page("Import a game", "Choose an installation folder to identify its edition using bundled metadata.")
        layout.addWidget(self.label("Diablo I • GOG English research baseline", "eyebrow"))
        layout.addWidget(self.label("Edition identification is available. Asset extraction and full compatibility verification are pending M2.", "muted"))
        row = QHBoxLayout()
        self.folder = QLineEdit(self.store.get("last_folder", ""))
        self.folder.setPlaceholderText("Select your installed game folder")
        browse = QPushButton("Browse…")
        browse.clicked.connect(self.browse_folder)
        row.addWidget(self.folder, 1)
        row.addWidget(browse)
        layout.addLayout(row)
        self.inspect = QPushButton("Identify edition")
        self.inspect.clicked.connect(self.start_inspection)
        layout.addWidget(self.inspect)
        self.cancel = QPushButton("Cancel inspection")
        self.cancel.setEnabled(False)
        self.cancel.clicked.connect(lambda: self.worker.requestInterruption() if self.worker else None)
        layout.addWidget(self.cancel)
        self.progress = QProgressBar()
        layout.addWidget(self.progress)
        self.inspection_status = self.label("No installation selected.", "muted")
        layout.addWidget(self.inspection_status)
        layout.addStretch()
        return page

    def placeholder_page(self, heading, title, description):
        page, layout = self.page(heading, title)
        layout.addWidget(self.label(description, "muted"))
        layout.addStretch()
        return page

    def settings_page(self):
        page, layout = self.page("Settings", "Local configuration. No accounts or cloud services.")
        layout.addWidget(self.label("Godot executable • tested version 4.6.2", "eyebrow"))
        self.godot_path = QLineEdit(self.store.get("godot_path", ""))
        self.godot_path.setPlaceholderText("Auto-detect pinned local executable or GODOT_BIN")
        layout.addWidget(self.godot_path)
        button = QPushButton("Choose executable…")
        button.clicked.connect(self.browse_godot)
        layout.addWidget(button)
        save = QPushButton("Save settings")
        save.clicked.connect(lambda: self.store.set("godot_path", self.godot_path.text().strip()))
        layout.addWidget(save)
        layout.addWidget(self.label("Bundled profiles: " + ", ".join(p["edition_id"] for p in profiles()), "muted"))
        layout.addStretch()
        return page

    def browse_folder(self):
        folder = QFileDialog.getExistingDirectory(self, "Select game installation", self.folder.text())
        if folder:
            self.folder.setText(folder)

    def browse_godot(self):
        path, _ = QFileDialog.getOpenFileName(self, "Select Godot 4.6.2 executable")
        if path:
            self.godot_path.setText(path)

    def start_inspection(self):
        if self.worker and self.worker.isRunning():
            return
        self.store.set("last_folder", self.folder.text())
        self.inspect.setEnabled(False)
        self.cancel.setEnabled(True)
        self.progress.setValue(0)
        self.inspection_status.setText("Checking edition fingerprint…")
        self.worker = InspectionWorker(self.folder.text(), self)
        self.worker.progress.connect(self.progress.setValue)
        self.worker.result.connect(self.inspection_done)
        self.worker.failure.connect(self.inspection_status.setText)
        self.worker.cancelled.connect(lambda: self.inspection_status.setText("Inspection cancelled."))
        self.worker.finished.connect(self.inspection_finished)
        self.worker.start()

    def inspection_done(self, details):
        self.store.save_installation(details)
        self.inspection_status.setText(details["status"] + "\n" + details["message"])
        self.refresh_library()

    def inspection_finished(self):
        self.inspect.setEnabled(True)
        self.cancel.setEnabled(False)

    def refresh_library(self):
        entries = self.store.installations()
        self.installed.setText("\n".join(entry["path"] + " — " + entry["status"] for entry in entries) or "No game installation registered. The demo is always available.")

    def launch_demo(self, smoke=False):
        if self.runtime.state() != QProcess.ProcessState.NotRunning or self.preparation.state() != QProcess.ProcessState.NotRunning:
            return
        try:
            import json
            validate_document(json.loads((ROOT / "demo_assets/demo_manifest.json").read_text(encoding="utf-8")), "game_manifest.schema.json")
            binary = find_godot(self.godot_path.text().strip())
        except Exception as exc:
            self.log.appendPlainText(str(exc))
            if smoke:
                from PyQt6.QtWidgets import QApplication
                QApplication.instance().exit(1)
            return
        self.runtime_output = ""
        self.play.setEnabled(False)
        self.pending_binary = binary
        self.pending_smoke = smoke
        if not list((ROOT / "runtime/.godot/imported").glob("hero.svg-*.ctex")):
            self.log.appendPlainText("Preparing original demo resources…")
            self.preparation.start(binary, ["--headless", "--path", str(ROOT / "runtime"), "--editor", "--import"])
        else:
            self.runtime.start(binary, demo_arguments(smoke))

    def prepared(self, code, status):
        output = bytes(self.preparation.readAllStandardOutput()).decode("utf-8", errors="replace")
        if code != 0 or status != QProcess.ExitStatus.NormalExit or "SCRIPT ERROR" in output:
            self.preparation_failed(output)
            return
        self.runtime.start(self.pending_binary, demo_arguments(self.pending_smoke))

    def preparation_failed(self, message):
        self.log.appendPlainText("Runtime preparation failed: " + message)
        self.play.setEnabled(True)
        if getattr(self, "pending_smoke", False):
            from PyQt6.QtWidgets import QApplication
            QApplication.instance().exit(1)

    def read_runtime(self):
        text = bytes(self.runtime.readAllStandardOutput()).decode("utf-8", errors="replace")
        self.runtime_output += text
        if text.strip():
            self.log.appendPlainText(text.rstrip())

    def runtime_error(self, error):
        self.log.appendPlainText(self.runtime.errorString())
        self.play.setEnabled(True)

    def runtime_finished(self, code, status):
        self.read_runtime()
        self.play.setEnabled(True)
        self.log.appendPlainText(f"Runtime exited: {code}")

    def closeEvent(self, event):
        if self.worker and self.worker.isRunning():
            self.worker.requestInterruption()
            self.inspection_status.setText("Cancelling inspection; close again once it stops.")
            event.ignore()
            return
        if self.preparation.state() != QProcess.ProcessState.NotRunning:
            self.preparation.kill()
            self.preparation.waitForFinished(1000)
        if self.runtime.state() != QProcess.ProcessState.NotRunning:
            self.runtime.terminate()
            if not self.runtime.waitForFinished(1000):
                self.runtime.kill()
                self.runtime.waitForFinished(1000)
        event.accept()
