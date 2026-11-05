#!/usr/bin/env sh
set -eu
cd "$(dirname "$0")/.."
python3 -m manager.app "$@"
