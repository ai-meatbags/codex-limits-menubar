[English](README.md) | [Русский](README.ru.md)

# Codex Limits Menu Bar

Native macOS menu bar app that shows your current Codex usage limits by talking to the local `codex app-server`.

This repository is intentionally focused on one supported path:

- data source — local `codex app-server`
- transport — stdio JSON-RPC
- menu bar shell — Swift + AppKit

No browser scraping, DOM parsing, Playwright session reuse, or private web endpoints are part of the product.

## Why this exists

Codex usage limits are useful operational feedback, but the default flow requires opening a UI and checking usage manually. This app keeps that signal visible in the macOS menu bar so you can decide faster whether to continue a session or slow down.

## Design Note

Earlier iterations of this project explored web-based acquisition paths through ChatGPT pages and private endpoints. Those experiments were removed from the open-source version on purpose.

Why:

- they depend on unsupported and brittle behavior
- they are hard to explain and maintain in a public repo
- they optimize for a one-off hack, not for a trustworthy open-source tool

The public version uses a single architectural bet: if the local Codex client can expose rate-limit information through `codex app-server`, the menu bar app should consume exactly that and nothing else.

## What the app shows

- a compact menu bar title with the main remaining percentages
- reset times for the visible buckets
- a dropdown with usage bars
- account label when `account/read` returns identity details
- quick actions for refresh, usage page, logs, and quit

If loading fails, the app falls back to an error snapshot instead of showing stale or invented data.

## Requirements

- macOS
- `codex` installed locally and available in `PATH`
- active `codex login`
- `node` installed locally
- Xcode command line tools available (`xcrun swiftc`)

## Quick Start

Build and open the app:

```bash
npm run menubar:app
```

Build the release bundle without opening it:

```bash
npm run menubar:app:build
```

The built app is placed at:

```bash
dist/CodexLimitsMenuBar.app
```

That `dist/` folder is the release handoff folder for creating a macOS release artifact.

## Runtime Flow

1. The Swift menu bar app starts.
2. It launches the bundled Node snapshot script.
3. The Node script runs `codex app-server`.
4. It sends JSON-RPC requests:
   - `initialize`
   - `account/read`
   - `account/rateLimits/read`
5. The response is normalized into a compact snapshot shape.
6. Swift renders the snapshot in the menu bar and refreshes periodically.

The release bundle does not bake the builder machine's absolute `node` or `codex` paths into the app. At runtime it looks for standard CLI locations and also respects explicit overrides.

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

## Product Boundaries

This repository does not aim to:

- reverse engineer ChatGPT web traffic
- store browser sessions or cookies
- depend on private or undocumented web endpoints
- support non-macOS menu bar environments

That constraint is a feature, not a limitation: the open-source version should stay understandable, auditable, and supportable.
