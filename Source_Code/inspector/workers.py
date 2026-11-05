from PyQt6.QtCore import QThread, pyqtSignal
from inspector.services.workspace import Cancelled

class Job(QThread):
    progress = pyqtSignal(int, str)
    result = pyqtSignal(object)
    failure = pyqtSignal(str)
    cancelled = pyqtSignal()
    def __init__(self, operation, parent=None):
        super().__init__(parent)
        self.operation = operation
    def run(self):
        try:
            result = self.operation(self.progress.emit, self.isInterruptionRequested)
            self.result.emit(result)
        except Cancelled:
            self.cancelled.emit()
        except Exception as exc:
            self.failure.emit(str(exc))
