"""Developer/CI setup; use an existing pinned Godot if already installed."""
import hashlib
import io
import json
import os
import platform
import sys
import urllib.request
import zipfile
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
VERSION = "4.6.2"

def main():
    if sys.platform == "win32":
        filename = f"Godot_v{VERSION}-stable_win64.exe.zip"
        executable = f"Godot_v{VERSION}-stable_win64_console.exe"
    elif sys.platform == "darwin":
        filename = f"Godot_v{VERSION}-stable_macos.universal.zip"
        executable = "Godot.app/Contents/MacOS/Godot"
    elif platform.machine().lower() in {"x86_64", "amd64"}:
        filename = f"Godot_v{VERSION}-stable_linux.x86_64.zip"
        executable = f"Godot_v{VERSION}-stable_linux.x86_64"
    else:
        raise SystemExit("Set GODOT_BIN to a native Godot 4.6.2 build on this architecture")
    base = f"https://github.com/godotengine/godot-builds/releases/download/{VERSION}-stable/"
    sums = urllib.request.urlopen(base + "SHA512-SUMS.txt", timeout=60).read().decode()
    expected = next((line.split()[0] for line in sums.splitlines() if len(line.split()) == 2 and line.split()[-1].lstrip("*") == filename), None)
    if not expected: raise SystemExit("Official Godot checksum missing")
    data = urllib.request.urlopen(base + filename, timeout=60).read(256 * 1024 * 1024 + 1)
    if len(data) > 256 * 1024 * 1024 or hashlib.sha512(data).hexdigest() != expected:
        raise SystemExit("Godot download size/checksum mismatch")
    target = ROOT / ".tools" / f"godot-{VERSION}"
    target.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(io.BytesIO(data)) as archive:
        for member in archive.infolist():
            destination = (target / member.filename).resolve()
            if not destination.is_relative_to(target.resolve()): raise SystemExit("Unsafe ZIP member")
            if not member.is_dir():
                destination.parent.mkdir(parents=True, exist_ok=True)
                destination.write_bytes(archive.read(member))
                mode = (member.external_attr >> 16) & 0o777
                if mode: destination.chmod(mode)
    binary = target / executable
    if sys.platform != "win32": binary.chmod(0o755)
    settings = ROOT / ".local/tooling.json"
    settings.parent.mkdir(exist_ok=True)
    settings.write_text(json.dumps({"godot_path": str(binary)}, indent=2))
    print(binary)

if __name__ == "__main__":
    main()
