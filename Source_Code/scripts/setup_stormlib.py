"""Install the pinned official Windows archive reader into ignored local tooling."""
import hashlib
import io
import sys
import urllib.request
import zipfile
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
URL = "https://github.com/ladislav-zezula/StormLib/releases/download/v9.40/stormlib_dll.zip"
SHA256 = "b2c9635e7b63edee1bd7c82e7dc180d739f3accb2b8994804c7774e464ce89ae"

def main():
    if sys.platform != "win32":
        raise SystemExit("Install StormLib 9.40 using your native package/build tools and set STORMLIB_PATH to the shared library.")
    data = urllib.request.urlopen(URL, timeout=60).read(32 * 1024 * 1024 + 1)
    if len(data) > 32 * 1024 * 1024 or hashlib.sha256(data).hexdigest() != SHA256:
        raise SystemExit("StormLib download size/checksum mismatch")
    destination = ROOT / ".tools/stormlib-9.40"
    destination.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(io.BytesIO(data)) as archive:
        for name in ("x64/StormLib.dll", "Win32/StormLib.dll", "History.txt"):
            target = destination / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(archive.read(name))
    print("Installed StormLib 9.40; official asset SHA-256 verified.")

if __name__ == "__main__":
    main()
