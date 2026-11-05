import os
import shutil
import sys
from pathlib import Path
from manager.services.paths import ROOT
GODOT_VERSION = "4.6.2"

def find_godot(configured=""):
    if getattr(sys,"frozen",False):
        executable=ROOT/"game/DiabloSurvivorsGame.exe"
        if not executable.is_file():raise FileNotFoundError("Bundled game executable is missing. Extract the complete release ZIP.")
        return str(executable)
    candidate = configured or os.environ.get("GODOT_BIN", "")
    if candidate:
        found = shutil.which(candidate) or (str(Path(candidate).expanduser().resolve()) if Path(candidate).expanduser().is_file() else None)
        if not found:
            raise FileNotFoundError("Configured Godot executable does not exist. Update Settings.")
        return found
    local_settings = ROOT / ".local/tooling.json"
    if local_settings.is_file():
        import json
        saved = json.loads(local_settings.read_text()).get("godot_path", "")
        if saved and Path(saved).is_file():
            return saved
    local = ROOT / ".tools" / "godot-4.6.2"
    matches = sorted(local.glob("Godot*console.exe")) + sorted(local.glob("Godot*.exe")) + sorted(local.glob("Godot*.x86_64"))
    for path in matches:
        if path.is_file():
            return str(path)
    for name in ("godot", "godot4"):
        if path := shutil.which(name):
            return path
    raise FileNotFoundError("Godot 4.6.2 was not found. Select its executable in Settings or set GODOT_BIN.")

def demo_arguments(smoke=False):
    args = ["--path", str(ROOT / "runtime")]
    if smoke:
        args = ["--headless"] + args
    args += ["res://scenes/main.tscn", "--", "--manifest", str(ROOT / "demo_assets/demo_manifest.json")]
    if smoke:
        args += ["--smoke-test"]
    return args
