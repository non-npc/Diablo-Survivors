import argparse
import json
import sys
from pathlib import Path
from manager.services.paths import ROOT

def main():
    parser = argparse.ArgumentParser(description="GameShift administrator game inspector")
    parser.add_argument("--folder", default="")
    parser.add_argument("--workspace", default=str(ROOT / ".local/inspector"))
    parser.add_argument("--prepare", action="store_true", help="Automatically build the database, profile/catalog and working imports without a GUI")
    parser.add_argument("--scan", action="store_true", help="Inspect without opening the GUI")
    parser.add_argument("--import-known", action="store_true", help="Import named catalog resources after a CLI scan")
    parser.add_argument("--smoke-test", action="store_true")
    parser.add_argument("--capture", default="")
    args = parser.parse_args()
    if args.prepare:
        from inspector.services.preparation import prepare_installation
        result = prepare_installation(args.folder, args.workspace, progress=lambda value, message: print(f"{value}% {message}", flush=True))
        print(json.dumps({k: v for k, v in result.items() if k not in {"report", "profile", "catalog", "imported"}}, indent=2))
        return 0
    if args.scan:
        from inspector.services.workspace import scan_installation, import_resources
        report = scan_installation(args.folder, args.workspace, progress=lambda value, message: print(f"{value}% {message}", flush=True))
        print(json.dumps([{k: v for k, v in a.items() if k != "assets"} for a in report["archives"]], indent=2))
        if args.import_known:
            selected = [(a["relative_path"], row) for a in report["archives"] for row in a["assets"] if row["source_path"]]
            result = import_resources(report, selected, args.workspace, progress=lambda value, message: print(f"{value}% {message}", flush=True))
            print(json.dumps(result, indent=2))
        return 0
    from PyQt6.QtCore import QTimer
    from PyQt6.QtWidgets import QApplication
    from inspector.ui.window import InspectorWindow
    app = QApplication(sys.argv[:1])
    from manager.ui.fonts import configure_fonts
    configure_fonts(app)
    window = InspectorWindow(args.workspace, args.folder)
    window.show()
    if args.capture:
        def capture():
            Path(args.capture).parent.mkdir(parents=True, exist_ok=True)
            window.grab().save(args.capture)
            app.quit()
        QTimer.singleShot(300, capture)
    elif args.smoke_test:
        QTimer.singleShot(200, app.quit)
    try:
        result = app.exec()
    finally:
        if window.job and window.job.isRunning():
            window.job.requestInterruption()
            window.job.wait()
    if result == 0 and args.smoke_test: print("GAMESHIFT_INSPECTOR_OK")
    return result

if __name__ == "__main__":
    raise SystemExit(main())
