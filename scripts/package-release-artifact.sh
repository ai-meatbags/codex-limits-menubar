#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_PATH="$DIST_DIR/CodexLimitsMenuBar.app"
VERSION="$(node -p "require('$ROOT_DIR/package.json').version")"
ARCHIVE_BASENAME="CodexLimitsMenuBar-v${VERSION}-macos"
ARCHIVE_PATH="$DIST_DIR/$ARCHIVE_BASENAME.zip"
CHECKSUM_PATH="$ARCHIVE_PATH.sha256"

bash "$ROOT_DIR/scripts/build-codex-limits-menubar-swift-app.sh"

rm -f "$ARCHIVE_PATH" "$CHECKSUM_PATH"
cd "$DIST_DIR"
/usr/bin/zip -r "$ARCHIVE_PATH" "CodexLimitsMenuBar.app" >/dev/null
/usr/bin/shasum -a 256 "$(basename "$ARCHIVE_PATH")" > "$CHECKSUM_PATH"

echo "Created $ARCHIVE_PATH"
echo "Created $CHECKSUM_PATH"
