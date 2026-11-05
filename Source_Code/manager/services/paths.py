import os
import sys
from pathlib import Path
ROOT = Path(sys.executable).resolve().parent if getattr(sys,"frozen",False) else Path(__file__).resolve().parents[2]

def data_dir(portable=False):
    override = os.environ.get("GAMESHIFT_DATA_DIR")
    if override:
        return Path(override).expanduser().resolve()
    if portable:
        return ROOT / ".local"
    if sys.platform == "win32":
        return Path(os.environ.get("LOCALAPPDATA", Path.home() / "AppData/Local")) / "GameShift"
    if sys.platform == "darwin":
        return Path.home() / "Library/Application Support/GameShift"
    return Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share")) / "gameshift"
