#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_PATH="$DIST_DIR/CodexLimitsMenuBar.app"
MACOS_DIR="$APP_PATH/Contents/MacOS"
RESOURCES_DIR="$APP_PATH/Contents/Resources"
RUNTIME_DIR="$RESOURCES_DIR/runtime"

rm -rf "$APP_PATH"
mkdir -p "$MACOS_DIR" "$RUNTIME_DIR"

cat > "$APP_PATH/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>CodexLimitsMenuBar</string>
  <key>CFBundleIdentifier</key>
  <string>local.codex.limits.menubar</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>CodexLimitsMenuBar</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSUIElement</key>
  <true/>
</dict>
</plist>
EOF

cat > "$RUNTIME_DIR/config.json" <<EOF
{
  "pollSeconds": 60
}
EOF

cp -R "$ROOT_DIR/src" "$RUNTIME_DIR/src"

xcrun swiftc \
  "$ROOT_DIR/macos/CodexLimitsMenuBar/AppLogger.swift" \
  "$ROOT_DIR/macos/CodexLimitsMenuBar/MenuPreviewFactory.swift" \
  "$ROOT_DIR/macos/CodexLimitsMenuBar/SnapshotModels.swift" \
  "$ROOT_DIR/macos/CodexLimitsMenuBar/SnapshotLoader.swift" \
  "$ROOT_DIR/macos/CodexLimitsMenuBar/AppDelegate.swift" \
  "$ROOT_DIR/macos/CodexLimitsMenuBar/main.swift" \
  -o "$MACOS_DIR/CodexLimitsMenuBar"

chmod +x "$MACOS_DIR/CodexLimitsMenuBar"
echo "Built $APP_PATH"
echo "Logs: ~/Library/Logs/CodexLimitsMenuBar/app.log"
