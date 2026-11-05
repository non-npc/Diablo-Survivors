import sys
from pathlib import Path
from PyQt6.QtGui import QFont, QFontDatabase

def configure_fonts(app):
    # Windows offscreen Qt has no native font database. Load an existing system
    # font for preview/check runs; do not bundle or copy proprietary fonts.
    if sys.platform == "win32" and not QFontDatabase.families():
        import os
        path = Path(os.environ.get("WINDIR", "C:/Windows")) / "Fonts/segoeui.ttf"
        if path.is_file():
            key = QFontDatabase.addApplicationFont(str(path))
            families = QFontDatabase.applicationFontFamilies(key)
            if families: app.setFont(QFont(families[0], 10))
