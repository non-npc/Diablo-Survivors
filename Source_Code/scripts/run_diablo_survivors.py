"""Launch Diablo Survivors from a source checkout."""
from pathlib import Path
import runpy
if __name__ == "__main__":
    runpy.run_path(str(Path(__file__).with_name("run_gameshift.py")), run_name="__main__")
