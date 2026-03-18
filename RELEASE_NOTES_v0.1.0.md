# Codex Limits Menu Bar v0.1.0

First public release.

## Highlights

- Native macOS menu bar app built with Swift and AppKit
- Usage snapshot flow powered by local `codex app-server`
- English and Russian README variants
- Portable release bundle that does not hardcode the builder machine's `node` or `codex` paths
- Dark-theme fix for the custom menu preview

## Requirements

- macOS
- local `codex` installation
- active `codex login`
- local `node` installation

## Included release artifacts

- `CodexLimitsMenuBar-v0.1.0-macos.zip`
- `CodexLimitsMenuBar-v0.1.0-macos.zip.sha256`

## Notes

- This project intentionally does not use browser scraping, private ChatGPT endpoints, or persisted browser sessions
- The app expects `codex` and `node` to be present on the machine where the release artifact is launched
