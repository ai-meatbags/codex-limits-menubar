[English](README.md) | [Русский](README.ru.md)

# Codex Limits Menu Bar

Native macOS menu bar app that shows your current Codex usage limits.

It reads usage data from your local `codex` installation and keeps the signal visible in the menu bar, so you do not need to keep opening the usage screen to see how much budget is left.

## Why this exists

Codex usage limits are useful operational feedback, but the default flow requires opening a UI and checking usage manually. This app keeps that signal visible in the macOS menu bar so you can decide faster whether to continue a session or slow down.

## What the app shows

- a compact menu bar title with the main remaining percentages
- reset times for the visible buckets
- a dropdown with usage bars
- account label when `account/read` returns identity details
- quick actions for refresh, usage page, logs, and quit

If loading fails, the app falls back to an error snapshot instead of showing stale or invented data.

## Requirements

### To run a downloaded release artifact

- macOS
- `codex` installed locally and available in `PATH`
- active `codex login`
- `node` installed locally

### To build from source

- all runtime requirements above
- Xcode command line tools available (`xcrun swiftc`)
- no external npm dependencies are required at the moment

## Quick Start

Build and open the app:

```bash
npm run menubar:app
```

Build the release bundle without opening it:

```bash
npm run menubar:app:build
```

Package a GitHub-ready release artifact:

```bash
npm run release:artifact
```

The built app is placed at:

```bash
dist/CodexLimitsMenuBar.app
```

The packaged release artifacts are placed in:

```bash
dist/CodexLimitsMenuBar-v<version>-macos.zip
dist/CodexLimitsMenuBar-v<version>-macos.zip.sha256
```

`dist/` is the output folder for release builds and packaged artifacts.

## How it works

1. The Swift menu bar app starts.
2. It launches the bundled Node snapshot script.
3. The Node script runs `codex app-server`.
4. It sends JSON-RPC requests:
   - `initialize`
   - `account/read`
   - `account/rateLimits/read`
5. The response is normalized into a compact snapshot shape.
6. Swift renders the snapshot in the menu bar and refreshes periodically.

The release bundle looks up `node` and `codex` on the machine where the app is launched and also respects explicit overrides when needed.

## Project Structure

- `macos/CodexLimitsMenuBar` — AppKit menu bar shell
- `src/cli/codex-limits-menubar-snapshot.mjs` — snapshot entrypoint
- `src/app-server/jsonlAppServerClient.mjs` — app-server JSON-RPC client
- `src/rate-limits/menubarSnapshot.mjs` — response normalization and view snapshot shaping
- `scripts/build-codex-limits-menubar-swift-app.sh` — build `.app` bundle into `dist/`
- `scripts/run-codex-limits-menubar-app.sh` — build and open the app

## Environment Variables

- `CODEX_LIMITS_CODEX_BIN` — override `codex` binary path
- `CODEX_LIMITS_NODE_BIN` — override `node` binary path used inside the app bundle
- `CODEX_LIMITS_LOG_FILE` — override log file path
- `CODEX_LIMITS_TIMEOUT_MS` — override request timeout for app-server calls

If you launch the `.app` from Finder and your tools live outside normal shell locations, set `CODEX_LIMITS_NODE_BIN` and `CODEX_LIMITS_CODEX_BIN` explicitly before starting the app.

## Logging

Default log file:

```bash
~/Library/Logs/CodexLimitsMenuBar/app.log
```

The app logs:

- startup and refresh lifecycle
- app-server stderr
- snapshot parse failures
- runtime execution errors

## Troubleshooting

### The app shows unavailable limits

Check:

- `codex` is installed and works in your shell
- `codex login` is active
- the bundled app can resolve the correct `node` and `codex` binaries
- the log file contains a successful `initialize` and `account/rateLimits/read`
- if needed, launch with explicit `CODEX_LIMITS_NODE_BIN` / `CODEX_LIMITS_CODEX_BIN` overrides

### Build fails

Check:

- `xcrun swiftc` is available
- `node` is available
- `codex` is installed before building, because the bundle captures its path into runtime config
