import argparse,sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
if __name__=="__main__":
    parser=argparse.ArgumentParser();parser.add_argument("--configure",action="store_true");parser.add_argument("--startup-check",metavar="REPORT");args=parser.parse_args()
    from manager.ui.game_selector import main
    if args.startup_check:
        from PyQt6.QtCore import QTimer
        from PyQt6.QtWidgets import QApplication
        from manager.ui.game_selector import GameSelector
        app=QApplication(sys.argv[:1])
        window=GameSelector(configure=True)
        def checked():
            Path(args.startup_check).write_text("QT_STARTUP_OK",encoding="utf-8")
            app.quit()
        QTimer.singleShot(200,checked)
        raise SystemExit(app.exec())
    raise SystemExit(main(args.configure))
