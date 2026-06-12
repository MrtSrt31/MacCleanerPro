#!/bin/zsh
# Builds the Full (direct-distribution) flavor: includes the complete app
# uninstaller, admin-authorized maintenance tools, and GPU/sensor monitoring.
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
FLAVOR=full "$ROOT_DIR/build_app.sh"
