import subprocess
import sys
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from manager.services.runtime import find_godot, demo_arguments
binary = find_godot()
subprocess.run([binary, "--headless", "--path", str(ROOT / "runtime"), "--editor", "--import"], check=True)
raise SystemExit(subprocess.call([binary] + demo_arguments()))
