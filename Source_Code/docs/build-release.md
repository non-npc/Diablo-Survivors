# Build and release

Use Python 3.12+ with pinned requirements and Godot 4.6.2. This workstation uses the existing executable recorded in `.local/tooling.json`. A fresh machine can select its executable in manager Settings or set `GODOT_BIN`; source build checks require the pinned version.

Windows: `scripts/build_windows.bat` uses installed Python packages, checks the manager/runtime, then packages source. It creates no virtual environment. Linux/macOS: invoke corresponding shell scripts with `sh`; provision Python packages and Godot first. On externally managed Python installations use the system's supported package installation configuration.

`python scripts/package_release.py` creates `dist/diablo-survivors-source.zip` from explicit source trees and top-level documentation/run files. It excludes `.local`, `.tools`, Godot caches and Python caches. This is not a standalone binary installer. Release-specific native/Qt license notices and platform installer testing are later gates.
