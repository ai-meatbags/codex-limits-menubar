#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_PATH="${1:-$ROOT_DIR/docs/images/menubar-screenshot.png}"
TMP_DIR="$(mktemp -d)"
RENDERER_SWIFT="$TMP_DIR/RenderScreenshot.swift"
RENDERER_BIN="$TMP_DIR/render-codex-limits-menubar-screenshot"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

cat > "$RENDERER_SWIFT" <<'EOF'
import Cocoa

@main
struct ScreenshotRenderer {
    static func main() {
        let outputPath = CommandLine.arguments.count > 1
            ? CommandLine.arguments[1]
            : "menubar-screenshot.png"

        let snapshot = MenubarSnapshot(
            ok: true,
            title: "1h 73% · 1d 41%",
            subtitle: "1h resets today 11:42 PM · 1d resets tomorrow 09:15 AM",
            errorMessage: nil,
            accountLabel: "ChatGPT account · chatgpt",
            buckets: [
                SnapshotBucket(
                    id: "primary-hourly",
                    windowLabel: "1h",
                    remainingPercent: 73,
                    resetLabel: "today 11:42 PM",
                    hasCredits: true,
                    title: "1h — 73% remaining",
                    subtitle: "Resets today 11:42 PM"
                ),
                SnapshotBucket(
                    id: "secondary-daily",
                    windowLabel: "1d",
                    remainingPercent: 41,
                    resetLabel: "tomorrow 09:15 AM",
                    hasCredits: true,
                    title: "1d — 41% remaining",
                    subtitle: "Resets tomorrow 09:15 AM"
                )
            ],
            updatedAt: ISO8601DateFormatter().string(from: Date())
        )

        let application = NSApplication.shared
        application.setActivationPolicy(.prohibited)
        application.appearance = NSAppearance(named: .darkAqua)

        let canvas = NSView(frame: NSRect(x: 0, y: 0, width: 520, height: 280))
        canvas.wantsLayer = true
        canvas.layer?.backgroundColor = NSColor(calibratedRed: 0.10, green: 0.11, blue: 0.14, alpha: 1).cgColor

        let menuBar = NSVisualEffectView(frame: NSRect(x: 0, y: 234, width: 520, height: 46))
        menuBar.material = .headerView
        menuBar.state = .active
        menuBar.appearance = NSAppearance(named: .darkAqua)
        menuBar.wantsLayer = true
        menuBar.layer?.backgroundColor = NSColor(calibratedWhite: 0.18, alpha: 0.92).cgColor
        canvas.addSubview(menuBar)

        let chip = NSVisualEffectView(frame: NSRect(x: 290, y: 242, width: 194, height: 28))
        chip.material = .menu
        chip.state = .active
        chip.appearance = NSAppearance(named: .darkAqua)
        chip.wantsLayer = true
        chip.layer?.cornerRadius = 14
        chip.layer?.masksToBounds = true
        chip.layer?.backgroundColor = NSColor(calibratedWhite: 0.26, alpha: 0.92).cgColor

        let iconView = NSImageView(frame: NSRect(x: 12, y: 6, width: 16, height: 16))
        iconView.image = NSImage(systemSymbolName: "chart.bar.fill", accessibilityDescription: "Limits")
        iconView.contentTintColor = NSColor(calibratedWhite: 0.94, alpha: 1)
        chip.addSubview(iconView)

        let chipLabel = NSTextField(labelWithString: snapshot.title)
        chipLabel.frame = NSRect(x: 36, y: 4, width: 148, height: 20)
        chipLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        chipLabel.textColor = NSColor(calibratedWhite: 0.95, alpha: 1)
        chip.addSubview(chipLabel)

        canvas.addSubview(chip)

        if let preview = MenuPreviewFactory.usageBarsPreviewView(snapshot: snapshot) {
            preview.frame.origin = NSPoint(x: 144, y: 34)
            preview.wantsLayer = true
            preview.layer?.shadowColor = NSColor.black.cgColor
            preview.layer?.shadowOpacity = 0.28
            preview.layer?.shadowRadius = 18
            preview.layer?.shadowOffset = CGSize(width: 0, height: -8)
            canvas.addSubview(preview)
        }

        canvas.layoutSubtreeIfNeeded()

        guard let bitmap = canvas.bitmapImageRepForCachingDisplay(in: canvas.bounds) else {
            fputs("Failed to create bitmap representation\n", stderr)
            exit(1)
        }

        bitmap.size = canvas.bounds.size
        canvas.cacheDisplay(in: canvas.bounds, to: bitmap)

        guard let data = bitmap.representation(using: .png, properties: [:]) else {
            fputs("Failed to encode PNG\n", stderr)
            exit(1)
        }

        do {
            try data.write(to: URL(fileURLWithPath: outputPath))
        } catch {
            fputs("Failed to write screenshot: \(error)\n", stderr)
            exit(1)
        }

        print("Rendered \(outputPath)")
    }
}
EOF

mkdir -p "$(dirname "$OUTPUT_PATH")"

xcrun swiftc \
  "$ROOT_DIR/macos/CodexLimitsMenuBar/MenuPreviewFactory.swift" \
  "$ROOT_DIR/macos/CodexLimitsMenuBar/SnapshotModels.swift" \
  "$RENDERER_SWIFT" \
  -o "$RENDERER_BIN"

"$RENDERER_BIN" "$OUTPUT_PATH"
