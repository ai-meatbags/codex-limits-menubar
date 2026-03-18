#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="$ROOT_DIR/dist/CodexLimitsMenuBar.app"

bash "$ROOT_DIR/scripts/build-codex-limits-menubar-swift-app.sh"
open "$APP_PATH"
