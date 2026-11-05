from PyQt6.QtCore import QThread, pyqtSignal
from manager.services.catalog import inspect_installation, InspectionCancelled

class InspectionWorker(QThread):
    progress = pyqtSignal(int)
    result = pyqtSignal(dict)
    failure = pyqtSignal(str)
    cancelled = pyqtSignal()
    def __init__(self, folder, parent=None):
        super().__init__(parent)
        self.folder = folder
    def run(self):
        try:
            details = inspect_installation(self.folder, self.progress.emit, self.isInterruptionRequested)
            if self.isInterruptionRequested():
                self.cancelled.emit()
            else:
                self.result.emit(details)
        except InspectionCancelled:
            self.cancelled.emit()
        except Exception as exc:
            self.failure.emit(str(exc))
