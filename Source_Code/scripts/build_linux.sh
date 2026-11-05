#!/usr/bin/env sh
set -eu
cd "$(dirname "$0")/.."
python3 -m pip install -r requirements-dev.txt
python3 scripts/check.py
python3 scripts/package_release.py
