import io
import json
from pathlib import Path
from PyQt6.QtCore import Qt, QTimer, QUrl, QProcess
from PyQt6.QtGui import QPixmap
from PyQt6.QtWidgets import (QMainWindow, QWidget, QVBoxLayout, QHBoxLayout, QFormLayout, QLineEdit, QLabel, QPushButton, QFileDialog, QTableWidget, QTableWidgetItem, QHeaderView, QSplitter, QPlainTextEdit, QProgressBar, QCheckBox, QAbstractItemView, QTabWidget, QComboBox, QSpinBox, QSlider)
from manager.ui.window import STYLE
from manager.services.paths import ROOT
from manager.services.runtime import find_godot
from manager.services.catalog import validate_document
from adapters.base.mpq import StormArchive
from inspector.workers import Job
from inspector.services.preparation import prepare_installation
from inspector.services.recognition import inspect_resource
from inspector.services.workspace import resource_type
from inspector.services.workspace import scan_installation, build_documents, save_documents, import_resources, candidate_names

class InspectorWindow(QMainWindow):
    def __init__(self, workspace, folder=""):
        super().__init__()
        self.workspace = Path(workspace).resolve()
        self.workspace.mkdir(parents=True, exist_ok=True)
        self.report = None
        self.job = None
        self.extra_names = set()
        self.asset_rows = []
        self.resource_index = {}
        self.preview_sheet = None
        self.preview_rects = []
        self.animation = QTimer(self)
        self.animation.setInterval(120)
        self.animation.timeout.connect(self.next_preview_frame)
        self.player = None
        self.runtime_manifest = None
        self.runtime_preview = QProcess(self)
        self.runtime_preview.setProcessChannelMode(QProcess.ProcessChannelMode.MergedChannels)
        self.runtime_preview.readyReadStandardOutput.connect(lambda: self.import_log.appendPlainText(bytes(self.runtime_preview.readAllStandardOutput()).decode("utf-8",errors="replace")))
        self.runtime_preview.errorOccurred.connect(lambda error:self.show_error(self.runtime_preview.errorString()))
        self.prepared_folder = None
        self.auto_timer = QTimer(self)
        self.auto_timer.setSingleShot(True)
        self.auto_timer.setInterval(650)
        self.auto_timer.timeout.connect(self.auto_prepare)
        self.setWindowTitle("GameShift — Game Inspector & Profile Studio")
        self.resize(1380, 920)
        self.setMinimumSize(1100, 750)
        self.setStyleSheet(STYLE)
        central = QWidget()
        self.setCentralWidget(central)
        layout = QVBoxLayout(central)
        layout.setContentsMargins(24, 20, 24, 20)
        heading = QLabel("Game Inspector & Profile Studio")
        heading.setObjectName("heading")
        layout.addWidget(heading)
        subtitle = QLabel("ADMINISTRATOR WORKSPACE  /  Inspect editions. Catalog resources. Import locally.")
        subtitle.setObjectName("eyebrow")
        layout.addWidget(subtitle)
        row = QHBoxLayout()
        self.folder = QLineEdit(folder)
        self.folder.setPlaceholderText("Game installation folder")
        self.browse = browse = QPushButton("Choose game folder…")
        browse.clicked.connect(self.browse_folder)
        self.scan = QPushButton("Refresh asset database")
        self.scan.setObjectName("primary")
        self.scan.clicked.connect(self.start_scan)
        row.addWidget(self.folder, 1)
        row.addWidget(browse)
        row.addWidget(self.scan)
        layout.addLayout(row)
        self.tabs = QTabWidget()
        layout.addWidget(self.tabs, 1)
        self.tabs.addTab(self.archive_page(), "Archives & assets")
        self.tabs.addTab(self.profile_page(), "Edition profile")
        self.tabs.addTab(self.import_page(), "Local imports")
        bottom = QHBoxLayout()
        self.progress = QProgressBar()
        self.progress.setValue(0)
        self.cancel = QPushButton("Cancel operation")
        self.cancel.setEnabled(False)
        self.cancel.clicked.connect(lambda: self.job.requestInterruption() if self.job else None)
        bottom.addWidget(self.progress, 1)
        bottom.addWidget(self.cancel)
        layout.addLayout(bottom)
        self.status = QLabel("Choose an installation folder. Source files are opened read-only.")
        self.status.setWordWrap(True)
        layout.addWidget(self.status)
        imported = self.workspace / "imports/latest.json"
        if imported.is_file():
            try:
                batch = json.loads(imported.read_text())["batch"]
                if Path(batch).name == batch:
                    self.import_log.setPlainText((imported.parent / batch / "index.json").read_text(encoding="utf-8"))
            except (OSError, ValueError, KeyError):
                pass
        previous = self.workspace / "last_inspection.json"
        if previous.is_file():
            try:
                self.scanned(json.loads(previous.read_text(encoding="utf-8")))
                if folder:
                    self.folder.setText(folder)
            except (ValueError, KeyError, TypeError):
                self.status.setText("Previous inspection could not be loaded. Inspect again.")

        # Selecting, pasting or typing a valid folder prepares its database.
        self.folder.textChanged.connect(lambda text: self.auto_timer.start())
        self.folder.editingFinished.connect(self.auto_prepare)
        latest = self.workspace / "last_preparation.json"
        if latest.is_file():
            try:
                saved = json.loads(latest.read_text(encoding="utf-8"))
                database = Path(saved["database_path"])
                game_workspace = database.parents[2]
                report = json.loads((game_workspace / "last_inspection.json").read_text(encoding="utf-8"))
                profile = json.loads(Path(saved["profile_path"]).read_text(encoding="utf-8"))
                catalog = json.loads(Path(saved["catalog_path"]).read_text(encoding="utf-8"))
                if not folder or Path(folder).resolve() == Path(saved["installation"]).resolve():
                    self.prepared({**saved, "report": report, "profile": profile, "catalog": catalog})
            except (OSError, ValueError, KeyError, IndexError):
                pass
        if folder:
            self.folder.setText(folder)
            QTimer.singleShot(0, self.auto_prepare)

    def auto_prepare(self):
        folder = self.folder.text().strip()
        if not folder or not Path(folder).is_dir():
            return
        if self.prepared_folder == str(Path(folder).resolve()):
            return
        self.start_scan()

    def archive_page(self):
        page = QWidget()
        layout = QVBoxLayout(page)
        self.archives = QTableWidget(0, 4)
        self.archives.setHorizontalHeaderLabels(["Profile", "Archive", "Bytes", "State"])
        self.archives.horizontalHeader().setSectionResizeMode(1, QHeaderView.ResizeMode.Stretch)
        self.archives.setSelectionBehavior(QAbstractItemView.SelectionBehavior.SelectRows)
        self.archives.setEditTriggers(QAbstractItemView.EditTrigger.NoEditTriggers)
        self.archives.setMaximumHeight(210)
        self.archives.itemSelectionChanged.connect(self.refresh_assets)
        layout.addWidget(self.archives)
        toolbar = QHBoxLayout()
        self.filter = QLineEdit()
        self.filter.setPlaceholderText("Filter internal paths")
        self.filter.textChanged.connect(self.refresh_assets)
        self.type_filter = QComboBox()
        self.type_filter.addItems(["All types", "image", "sprite", "audio", "terrain", "palette", "video", "text", "metadata", "binary", "unknown"])
        self.type_filter.currentTextChanged.connect(self.refresh_assets)
        self.named = QCheckBox("Named resources only")
        self.named.setChecked(True)
        self.named.toggled.connect(self.refresh_assets)
        listfile = QPushButton("Add candidate list…")
        listfile.clicked.connect(self.load_candidates)
        probe = QPushButton("Probe path…")
        probe.clicked.connect(self.probe_path)
        toolbar.addWidget(self.filter, 1)
        toolbar.addWidget(self.type_filter)
        toolbar.addWidget(self.named)
        toolbar.addWidget(listfile)
        toolbar.addWidget(probe)
        layout.addLayout(toolbar)
        split = QSplitter()
        self.assets = QTableWidget(0, 8)
        self.assets.setHorizontalHeaderLabels(["Internal path", "Type", "Format", "Details", "Block", "Stored", "Decoded", "Flags"])
        self.assets.horizontalHeader().setSectionResizeMode(0, QHeaderView.ResizeMode.Stretch)
        for column, width in enumerate((65, 60, 150, 55, 75, 75, 90), 1):
            self.assets.setColumnWidth(column, width)
        self.assets.setSelectionBehavior(QAbstractItemView.SelectionBehavior.SelectRows)
        self.assets.setSelectionMode(QAbstractItemView.SelectionMode.ExtendedSelection)
        self.assets.setEditTriggers(QAbstractItemView.EditTrigger.NoEditTriggers)
        preview = QWidget()
        pv = QVBoxLayout(preview)
        preview_button = QPushButton("Preview selected resource")
        preview_button.clicked.connect(self.preview_selected)
        pv.addWidget(preview_button)
        options = QHBoxLayout()
        options.addWidget(QLabel("Sprite width (0 = auto)"))
        self.preview_width = QSpinBox()
        self.preview_width.setRange(0, 4096)
        options.addWidget(self.preview_width)
        pv.addLayout(options)
        self.palette_choice = QComboBox()
        self.palette_choice.addItem("Catalog/default palette", None)
        self.translation_choice = QComboBox()
        self.translation_choice.addItem("No translation", None)
        self.direction_choice = QComboBox()
        from adapters.diablo1.validation import DIRECTIONS
        for i,name in enumerate(DIRECTIONS): self.direction_choice.addItem(name, i)
        pv.addWidget(self.palette_choice)
        pv.addWidget(self.translation_choice)
        pv.addWidget(self.direction_choice)
        self.frame_slider = QSlider(Qt.Orientation.Horizontal)
        self.frame_slider.valueChanged.connect(self.show_preview_frame)
        self.frame_slider.setEnabled(False)
        pv.addWidget(self.frame_slider)
        media = QHBoxLayout()
        self.animate_button = QPushButton("Animate")
        self.animate_button.clicked.connect(self.toggle_animation)
        self.animate_button.setEnabled(False)
        self.audio_button = QPushButton("Play audio")
        self.audio_button.clicked.connect(self.play_audio)
        self.audio_button.setEnabled(False)
        stop = QPushButton("Stop")
        stop.clicked.connect(self.stop_media)
        media.addWidget(self.animate_button)
        media.addWidget(self.audio_button)
        media.addWidget(stop)
        pv.addLayout(media)
        self.palette_preview = QLabel("Palette previews appear here")
        self.palette_preview.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.palette_preview.setMinimumHeight(150)
        self.palette_preview.setMaximumHeight(320)
        pv.addWidget(self.palette_preview)
        self.asset_details = QPlainTextEdit()
        self.asset_details.setReadOnly(True)
        pv.addWidget(self.asset_details)
        split.addWidget(self.assets)
        split.addWidget(preview)
        split.setSizes([850, 380])
        layout.addWidget(split, 1)
        self.asset_summary = QLabel("No archive selected")
        layout.addWidget(self.asset_summary)
        return page

    def profile_page(self):
        page = QWidget()
        layout = QVBoxLayout(page)
        description = QLabel("Select archives using the checkboxes, then save a versioned draft profile/catalog pair. Drafts stay inspected until extraction and gameplay mappings are validated.")
        description.setWordWrap(True)
        layout.addWidget(description)
        form = QFormLayout()
        self.fields = {}
        defaults = [("edition_id", "Edition ID", "diablo1-gog-en-1092"), ("game_id", "Game ID", "diablo1"), ("distribution", "Distribution", "GOG"), ("language", "Language", "en-US"), ("executable_product_version", "Executable product version", "1.0.9.2")]
        for key, label, value in defaults:
            field = QLineEdit(value)
            self.fields[key] = field
            form.addRow(label, field)
        layout.addLayout(form)
        actions = QHBoxLayout()
        self.save_profile = QPushButton("Save profile & catalog…")
        self.save_profile.setObjectName("primary")
        self.save_profile.clicked.connect(self.export_profile)
        load = QPushButton("Load profile…")
        load.clicked.connect(self.load_profile)
        actions.addWidget(self.save_profile)
        actions.addWidget(load)
        layout.addLayout(actions)
        self.profile_preview = QPlainTextEdit()
        self.profile_preview.setReadOnly(True)
        layout.addWidget(self.profile_preview, 1)
        return page

    def import_page(self):
        page = QWidget()
        layout = QVBoxLayout(page)
        explanation = QLabel("Selecting a game folder automatically builds its asset database, profile/catalog and local imports. Select specific named resources in Archives & assets to import an additional working batch. Images get decoded previews; audio includes format, channels and duration; supported CEL/CL2 sprites get frame previews; terrain tables are identified structurally. Some sprite widths, palette associations and full terrain assembly still need verified rules. Imported content stays local and is excluded from source packages.")
        explanation.setWordWrap(True)
        layout.addWidget(explanation)
        layout.addWidget(QLabel("Workspace: " + str(self.workspace)))
        self.import_button = QPushButton("Import selected named resources")
        self.import_button.setObjectName("primary")
        self.import_button.clicked.connect(self.start_import)
        layout.addWidget(self.import_button)
        self.runtime_button=QPushButton("Preview validated assets in Godot")
        self.runtime_button.setEnabled(False)
        self.runtime_button.clicked.connect(self.launch_runtime_preview)
        layout.addWidget(self.runtime_button)
        self.import_log = QPlainTextEdit()
        self.import_log.setReadOnly(True)
        layout.addWidget(self.import_log, 1)
        return page

    def browse_folder(self):
        folder = QFileDialog.getExistingDirectory(self, "Select installed game", self.folder.text())
        if folder: self.folder.setText(folder)

    def run_job(self, operation, callback):
        if self.job and self.job.isRunning(): return
        self.job = Job(operation, self)
        self.job.progress.connect(self.update_progress)
        self.job.result.connect(callback)
        self.job.failure.connect(self.show_error)
        self.job.cancelled.connect(lambda: self.status.setText("Operation cancelled; active imports preserved."))
        self.job.finished.connect(self.job_finished)
        self.folder.setEnabled(False)
        self.browse.setEnabled(False)
        self.scan.setEnabled(False)
        self.import_button.setEnabled(False)
        self.save_profile.setEnabled(False)
        self.cancel.setEnabled(True)
        self.job.start()

    def update_progress(self, value, message):
        self.progress.setValue(value)
        self.status.setText(message)

    def show_error(self, message):
        self.status.setText("Error: " + message)
        self.import_log.appendPlainText("Error: " + message)

    def job_finished(self):
        self.folder.setEnabled(True)
        self.browse.setEnabled(True)
        self.scan.setEnabled(True)
        self.import_button.setEnabled(True)
        self.save_profile.setEnabled(True)
        self.cancel.setEnabled(False)

    def start_scan(self):
        if not self.folder.text().strip():
            self.show_error("Select an installation folder")
            return
        folder = self.folder.text()
        self.auto_timer.stop()
        extra = tuple(self.extra_names)
        self.run_job(lambda progress, cancel: prepare_installation(folder, self.workspace, extra, progress, cancel), self.prepared)

    def prepared(self, result):
        self.prepared_folder = str(Path(result["installation"]).resolve())
        imported = result.get("imported", {})
        if not imported.get("assets") and result.get("import_output"):
            try:
                imported = json.loads((Path(result["import_output"]) / "index.json").read_text(encoding="utf-8"))
            except (OSError, ValueError): pass
        directory = result.get("import_output") or imported.get("output_dir")
        self.resource_index = {}
        if directory:
            for entry in imported.get("assets", []):
                self.resource_index[(entry["archive"], entry["source_path"])] = {**entry, "output_dir": directory}
        validation = result.get("validation", {})
        self.runtime_manifest = validation.get("runtime_preview_manifest")
        self.runtime_button.setEnabled(bool(self.runtime_manifest and Path(self.runtime_manifest).is_file()))
        self.palette_choice.clear(); self.palette_choice.addItem("Catalog/default palette", None)
        self.translation_choice.clear(); self.translation_choice.addItem("No translation", None)
        for key,entry in sorted(self.resource_index.items()):
            format_name = entry.get("identification", {}).get("format")
            if format_name == "RGB256": self.palette_choice.addItem(key[1], str(Path(entry["output_dir"])/entry["raw_path"]))
            if format_name == "TRN": self.translation_choice.addItem(key[1], str(Path(entry["output_dir"])/entry["raw_path"]))
        if validation.get("output_dir"):
            for animation in validation.get("animations", []):
                key = ("DIABDAT.MPQ", animation["source_path"].replace("/", "\\"))
                if key in self.resource_index:
                    self.resource_index[key]["validated_sheet"] = str(Path(validation["output_dir"])/animation["sheet"])
                    self.resource_index[key]["validated_animation"] = animation
            key=("DIABDAT.MPQ", "levels\\l1data\\l1.til")
            if key in self.resource_index:
                entry=self.resource_index[key]
                entry["validated_sheet"] = str(Path(validation["output_dir"])/validation["terrain_preview"])
                height=validation["terrain"]["tile_size"][1]
                entry["validated_terrain_rects"]=[{"frame":i,"x":i%8*128,"y":i//8*height,"width":128,"height":height} for i in range(validation["terrain"]["tile_count"])]
        self.scanned(result["report"])
        for key, field in self.fields.items():
            field.setText(result["profile"][key])
        self.profile_preview.setPlainText(json.dumps({"profile": result["profile"], "version_evidence": result["report"].get("metadata", {}), "saved_profile": result["profile_path"], "saved_catalog": result["catalog_path"]}, indent=2))
        self.import_log.setPlainText(json.dumps({k: v for k, v in result.items() if k not in {"report", "profile", "catalog"}}, indent=2))
        self.progress.setValue(100)
        self.status.setText(f"Database ready: {result['asset_count']:,} records, {result['named_count']} named, {result['imported_count']} imported. " + result["database_path"])

    def scanned(self, report):
        self.report = report
        self.profile_preview.setPlainText(json.dumps(report.get("metadata", {}), indent=2))
        self.folder.setText(report["installation"])
        self.archives.blockSignals(True)
        self.archives.setRowCount(len(report["archives"]))
        for i, archive in enumerate(report["archives"]):
            check = QTableWidgetItem()
            check.setFlags(Qt.ItemFlag.ItemIsUserCheckable | Qt.ItemFlag.ItemIsEnabled)
            check.setCheckState(Qt.CheckState.Checked if archive["relative_path"].lower() == "diabdat.mpq" else Qt.CheckState.Unchecked)
            self.archives.setItem(i, 0, check)
            for j, value in enumerate([archive["relative_path"], f"{archive['size_bytes']:,}", archive["state"]], 1):
                self.archives.setItem(i, j, QTableWidgetItem(str(value)))
        self.archives.blockSignals(False)
        if report["archives"]: self.archives.selectRow(0)
        self.refresh_assets()
        self.status.setText(f"{len(report['archives'])} unique archives inspected. Unnamed blocks are not guessed filenames.")

    def active_archive(self):
        if not self.report: return None
        row = self.archives.currentRow()
        return self.report["archives"][row] if 0 <= row < len(self.report["archives"]) else None

    def refresh_assets(self):
        archive = self.active_archive()
        if not archive: return
        needle = self.filter.text().strip().lower()
        kind = self.type_filter.currentText()
        self.asset_rows = [a for a in archive["assets"] if (a["source_path"] or not self.named.isChecked()) and (not needle or needle in a["source_path"].lower()) and (kind == "All types" or self.resource_index.get((archive["relative_path"], a["source_path"]), {}).get("type", resource_type(a["source_path"]) if a["source_path"] else "unknown") == kind)]
        self.assets.setRowCount(len(self.asset_rows))
        for i, asset in enumerate(self.asset_rows):
            name = asset["source_path"] or f"[unnamed block {asset['block_index']}]"
            entry = self.resource_index.get((archive["relative_path"], asset["source_path"]), {})
            info = entry.get("identification", {})
            detail = f"{info['width']} × {info['height']}" if "width" in info and "height" in info else ""
            if "duration_seconds" in info: detail = f"{info['duration_seconds']:.1f}s / {info['sample_rate']} Hz"
            if "frame_count" in info: detail += f" / {info['frame_count']} frames"
            values = [name, entry.get("type", resource_type(name) if asset["source_path"] else "unknown"), info.get("format", ""), detail, asset["block_index"], asset["stored_bytes"], asset["decoded_bytes"], asset["flags"]]
            for j, value in enumerate(values):
                self.assets.setItem(i, j, QTableWidgetItem(str(value)))
        known = sum(bool(a["source_path"]) for a in archive["assets"])
        self.asset_summary.setText(f"{known} named resources / {len(archive['assets'])} block records • showing {len(self.asset_rows)}")
        self.asset_details.setPlainText(json.dumps({k: v for k, v in archive.items() if k != "assets"}, indent=2))

    def load_candidates(self):
        path, _ = QFileDialog.getOpenFileName(self, "Choose candidate resource paths (one per line)", "", "Text files (*.txt);;All files (*)")
        if path:
            try:
                self.extra_names.update(n.strip() for n in Path(path).read_text(encoding="utf-8-sig").splitlines() if n.strip())
                self.start_scan()
            except Exception as exc: self.show_error(str(exc))

    def probe_path(self):
        from PyQt6.QtWidgets import QInputDialog
        path, ok = QInputDialog.getText(self, "Probe internal path", "Exact archive path:")
        if ok and path.strip():
            self.extra_names.add(path.strip())
            self.start_scan()

    def selected_resources(self):
        archive = self.active_archive()
        if not archive: return []
        return [(archive["relative_path"], self.asset_rows[index.row()]) for index in self.assets.selectionModel().selectedRows() if self.asset_rows[index.row()]["source_path"]]

    def preview_selected(self):
        selected = self.selected_resources()
        if not selected:
            self.show_error("Select a named resource first")
            return
        self.stop_media()
        archive_name, row = selected[0]
        cached = self.resource_index.get((archive_name, row["source_path"]), {})
        self.current_audio_path = None
        self.audio_button.setEnabled(False)
        if cached and self.preview_width.value() == 0 and self.palette_choice.currentData() is None and self.translation_choice.currentData() is None and (self.direction_choice.currentData() == 0 or cached.get("validated_animation")):
            info = dict(cached.get("identification", {}))
            preview_path = Path(cached["output_dir"])/cached["preview_path"] if cached.get("preview_path") else None
            if cached.get("validated_sheet"):
                preview_path = Path(cached["validated_sheet"])
                if cached.get("validated_animation"):
                    animation=cached["validated_animation"]; group=self.direction_choice.currentData()
                    width,height=animation["frame_size"]
                    info.update(preview_frames=[{"frame":i,"x":i*width,"y":group*height,"width":width,"height":height} for i in range(animation["frames_per_direction"][group])],palette_source="Validated representative: l1_1.pal + white.trn",preview_group=group)
                elif cached.get("validated_terrain_rects"):
                    info.update(preview_frames=cached["validated_terrain_rects"],preview_note="Composed cathedral CEL/MIN/TIL artwork; raw SOL flags are not a verified navigation mesh")
            self.asset_details.setPlainText(json.dumps({**row, "identification": info}, indent=2))
            self.load_image_preview(preview_path, info)
            if cached["type"] == "audio":
                self.current_audio_path = str(Path(cached["output_dir"]) / cached["raw_path"])
                self.audio_button.setEnabled(True)
            self.status.setText("Loaded cached identification and preview; no archive read")
            return
        archive = next(a for a in self.report["archives"] if a["relative_path"] == archive_name)
        width = self.preview_width.value()
        group = self.direction_choice.currentData()
        palette_path = self.palette_choice.currentData()
        translation_path = self.translation_choice.currentData()
        if palette_path is None and cached:
            source = cached.get("identification", {}).get("palette_source", {})
            if isinstance(source, dict):
                entry = self.resource_index.get((source.get("archive"), source.get("source_path", "").replace("/", "\\")))
                if entry: palette_path = str(Path(entry["output_dir"])/entry["raw_path"])
        if group >= cached.get("identification", {}).get("group_count", 8): group = 0
        def read(progress, cancel):
            if cached:
                data=(Path(cached["output_dir"])/cached["raw_path"]).read_bytes()
            else:
                with StormArchive(archive["path"]) as reader: data=reader.read(row["source_path"])
            palette = Path(palette_path).read_bytes() if palette_path else None
            translation = Path(translation_path).read_bytes() if translation_path else None
            info,image = inspect_resource(data,row["source_path"],width=width,preview_group=group,palette=palette,translation=translation)
            path = None
            if image is not None:
                import hashlib
                path = self.workspace / "manual-previews" / (hashlib.sha256((archive_name+row["source_path"]+str((width,group,palette_path,translation_path))).encode()).hexdigest()[:20]+".png")
                path.parent.mkdir(exist_ok=True)
                image.save(path)
            return (row,info,path,data[:128])
        self.run_job(read,self.preview_ready)

    def preview_ready(self, result):
        row, info, path, prefix = result
        self.asset_details.setPlainText(json.dumps({**row,"identification":info},indent=2)+"\n\nFirst 128 bytes:\n"+prefix.hex(" "))
        self.load_image_preview(path,info)
        self.status.setText("Resource identified: " + info["type"] + " / " + info["format"])

    def load_image_preview(self, path, info):
        self.animation.stop()
        self.preview_rects = info.get("preview_frames", [])
        self.preview_sheet = QPixmap(str(path)) if path and Path(path).is_file() else None
        self.frame_slider.blockSignals(True)
        self.frame_slider.setRange(0,max(0,len(self.preview_rects)-1))
        self.frame_slider.setValue(0)
        self.frame_slider.blockSignals(False)
        self.frame_slider.setEnabled(bool(self.preview_rects))
        self.animate_button.setEnabled(len(self.preview_rects)>1 and info.get("type")=="sprite")
        self.show_preview_frame(0)
        if self.preview_sheet is None:
            self.palette_preview.setText(info.get("preview_warning") or info.get("description") or "No visual preview for this resource")

    def show_preview_frame(self, index):
        if self.preview_sheet is None: return
        image = self.preview_sheet
        if self.preview_rects:
            frame = self.preview_rects[index]
            image = image.copy(frame["x"],frame["y"],frame["width"],frame["height"])
        self.palette_preview.setPixmap(image.scaled(340,280,Qt.AspectRatioMode.KeepAspectRatio,Qt.TransformationMode.FastTransformation))

    def next_preview_frame(self):
        if self.preview_rects:
            self.frame_slider.setValue((self.frame_slider.value()+1)%len(self.preview_rects))

    def toggle_animation(self):
        if self.animation.isActive(): self.animation.stop()
        else: self.animation.start()

    def play_audio(self):
        if not getattr(self,"current_audio_path",None): return
        if self.player is None:
            from PyQt6.QtMultimedia import QMediaPlayer,QAudioOutput
            self.player=QMediaPlayer(self)
            self.audio_output=QAudioOutput(self)
            self.audio_output.setVolume(0.5)
            self.player.setAudioOutput(self.audio_output)
            self.player.errorOccurred.connect(lambda error,message:self.show_error(message))
        self.player.setSource(QUrl.fromLocalFile(self.current_audio_path))
        self.player.play()

    def stop_media(self):
        self.animation.stop()
        if self.player is not None: self.player.stop()

    def export_profile(self):
        if not self.report:
            self.show_error("Inspect an installation first")
            return
        try:
            selected = [a["relative_path"] for i, a in enumerate(self.report["archives"]) if self.archives.item(i, 0).checkState() == Qt.CheckState.Checked]
            values = [self.fields[k].text().strip() for k in ["edition_id", "game_id", "distribution", "language", "executable_product_version"]]
            profile, catalog = build_documents(self.report, *values, selected)
            for asset in catalog["assets"]:
                entry = self.resource_index.get((asset["archive"], asset["source_path"]))
                if entry:
                    asset["type"] = entry["type"]
                    asset["identification"] = {k: v for k, v in entry.get("identification", {}).items() if k != "text_preview"}
            destination = QFileDialog.getExistingDirectory(self, "Save draft profile/catalog in folder", str(self.workspace))
            if destination:
                if Path(destination).resolve().is_relative_to(Path(self.report["installation"]).resolve()):
                    raise ValueError("Save metadata outside the source game installation")
                path = save_documents(destination, profile, catalog)
                self.profile_preview.setPlainText(json.dumps({"profile": profile, "catalog": catalog}, indent=2))
                self.status.setText("Saved draft pair: " + path)
        except Exception as exc: self.show_error(str(exc))

    def load_profile(self):
        path, _ = QFileDialog.getOpenFileName(self, "Load edition profile", "", "JSON (*.json)")
        if path:
            try:
                profile = json.loads(Path(path).read_text(encoding="utf-8"))
                validate_document(profile, "edition_profile.schema.json")
                for key, field in self.fields.items(): field.setText(profile[key])
                paired = Path(path).with_name("catalog.json")
                if paired.exists():
                    catalog = json.loads(paired.read_text(encoding="utf-8"))
                    validate_document(catalog, "asset_catalog.schema.json")
                    self.extra_names.update(a["source_path"] for a in catalog["assets"])
                self.profile_preview.setPlainText(json.dumps(profile, indent=2))
                self.status.setText("Profile loaded. Inspect its installation to refresh evidence.")
            except Exception as exc: self.show_error(str(exc))

    def start_import(self):
        selected = self.selected_resources()
        if not selected:
            self.show_error("Select named rows in Archives & assets before importing")
            return
        self.run_job(lambda progress, cancel: import_resources(self.report, selected, self.workspace, progress, cancel), self.imported)

    def imported(self, result):
        self.import_log.setPlainText(json.dumps(result, indent=2))
        self.tabs.setCurrentIndex(2)
        self.status.setText("Local import ready: " + result["output_dir"])

    def launch_runtime_preview(self):
        if not self.runtime_manifest or self.runtime_preview.state()!=QProcess.ProcessState.NotRunning:return
        try:
            self.runtime_preview.start(find_godot(),["--path",str(ROOT/"runtime"),"res://scenes/import_preview.tscn","--","--preview-manifest",self.runtime_manifest])
        except Exception as exc:self.show_error(str(exc))

    def closeEvent(self, event):
        self.stop_media()
        if self.runtime_preview.state()!=QProcess.ProcessState.NotRunning:
            self.runtime_preview.terminate()
            if not self.runtime_preview.waitForFinished(1000):self.runtime_preview.kill()
        if self.job and self.job.isRunning():
            self.job.requestInterruption()
            self.status.setText("Cancelling operation; close again after it stops.")
            event.ignore()
            return
        event.accept()
