#!/bin/zsh
# Builds the App Store flavor: advanced/system-altering tools (full uninstaller,
# admin-level maintenance, GPU/sensor monitoring) are compiled out.
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
FLAVOR=appstore "$ROOT_DIR/build_app.sh"
