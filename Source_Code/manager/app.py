import argparse
import sys
from PyQt6.QtCore import QProcess, QTimer
from PyQt6.QtWidgets import QApplication
from manager.db.store import Store
from manager.services.paths import data_dir
from manager.ui.window import MainWindow

def main():
    parser = argparse.ArgumentParser(description="GameShift desktop manager")
    parser.add_argument("--portable", action="store_true")
    parser.add_argument("--smoke-test", action="store_true")
    parser.add_argument("--launch-smoke", action="store_true")
    parser.add_argument("--godot", default="")
    args = parser.parse_args()
    app = QApplication(sys.argv[:1])
    from manager.ui.fonts import configure_fonts
    configure_fonts(app)
    app.setApplicationName("GameShift")
    app.setOrganizationName("GameShift")
    store = Store(data_dir(args.portable))
    window = MainWindow(store)
    if args.godot:
        window.godot_path.setText(args.godot)
    window.show()
    if args.launch_smoke:
        window.runtime.finished.connect(lambda code, status: app.exit(0 if code == 0 and status == QProcess.ExitStatus.NormalExit and "GAMESHIFT_SMOKE_OK" in window.runtime_output else 1))
        window.runtime.errorOccurred.connect(lambda error: app.exit(1))
        QTimer.singleShot(0, lambda: window.launch_demo(smoke=True))
        QTimer.singleShot(30000, lambda: app.exit(1))
    elif args.smoke_test:
        QTimer.singleShot(200, app.quit)
    try:
        result = app.exec()
    finally:
        if window.runtime.state() != QProcess.ProcessState.NotRunning:
            window.runtime.kill()
            window.runtime.waitForFinished(1000)
        store.close()
    if result == 0 and (args.smoke_test or args.launch_smoke):
        print("GAMESHIFT_MANAGER_OK")
    return result

if __name__ == "__main__":
    raise SystemExit(main())
