# Claude Usage

> A lightweight macOS menu bar app that shows your Claude Pro/Max usage in real time.

![macOS](https://img.shields.io/badge/macOS-13%2B-black?logo=apple)
![Swift](https://img.shields.io/badge/Swift-6-orange?logo=swift)
![License](https://img.shields.io/badge/license-MIT-blue)

---

## Overview

**Claude Usage** lives in your menu bar and keeps you informed about your Claude session at a glance — no browser tabs, no digging through settings.

```
🟠 61% · 2h 8m
```

Click the icon to open the full detail popover:

- **Session usage** — 5-hour rolling window with countdown timer
- **Weekly usage** — 7-day window with reset day/time
- **Daily Routines** — quota at a glance
- **Usage Credits** — ON/OFF status
- **Launch at Login** toggle
- One-click **Quit**

When a session hasn't started yet, it shows **0%** and prompts you to start a conversation — no confusing stale numbers.

---

## Features

- **Real-time data** — polls the Anthropic usage endpoint every 5 minutes
- **Color-coded indicators** — 🟢 0–60% · 🟠 61–85% · 🔴 86–100%
- **Smart notifications** — alerts at 80% and 95% session usage
- **Zero dependencies** — pure Swift, no Node, no Electron
- **Tiny footprint** — menu-bar only, no Dock icon, no background processes
- **Sign-in prompt** — graceful UI when Claude Code credentials aren't found
- **Launch at Login** — via `SMAppService`

---

## Requirements

- macOS 13 Ventura or later
- [Claude Code](https://claude.ai/download) installed and signed in
  *(the app reads your existing OAuth token — no separate login needed)*

---

## Installation

### Option A — DMG (recommended)

1. Download the latest `Claude.Usage-x.x.dmg` from [Releases](../../releases)
2. Open the DMG and drag **Claude Usage** to your Applications folder
3. Launch from Applications

### Option B — Build from source

```bash
git clone https://github.com/rtoedz/menubar-claude-usage.git
cd menubar-claude-usage
./make_app.sh
cp -R ClaudeUsageBar.app ~/Applications/
open ~/Applications/ClaudeUsageBar.app
```

> **Tip:** Install to `~/Applications/` (not just run from the project folder) so Launch at Login and notifications work correctly.

---

## How it works

Claude Usage reads your OAuth token from the same place Claude Code stores it:

1. `~/.claude/.credentials.json`
2. macOS Keychain (`Claude Code-credentials`)

It then calls `https://api.anthropic.com/api/oauth/usage` directly using `URLSession` — no subprocess, no extra runtime required.

---

## Build & distribute

```bash
# Dev run (no bundle features)
swift run

# Build .app bundle
./make_app.sh

# Build distributable DMG
./make_dmg.sh
```

---

## Project structure

```
Sources/ClaudeUsageBar/
├── main.swift          Entry point
├── AppDelegate.swift   NSStatusItem + NSPopover wiring
├── UsageManager.swift  API fetch, polling, model, notifications
└── PopoverView.swift   SwiftUI dark popover card
Resources/
└── AppIcon.icns        App icon (all sizes)
Info.plist              Bundle config (LSUIElement, bundle ID)
make_app.sh             Builds the release .app bundle
make_dmg.sh             Packages the app into a DMG installer
scripts/
└── generate_icon.swift Regenerates AppIcon.icns from source
```

---

## Notifications caveat

Notification code is complete, but macOS **suppresses alerts for ad-hoc-signed apps**. To receive banners, sign the bundle with a stable identity (Developer ID certificate or trusted self-signed cert).

---

## Debug flags

| Variable | Effect |
|----------|--------|
| `CUB_DEBUG_POPOVER=1` | Renders popover in a standalone window |
| `CUB_TEST_NOTIFY=1` | Fires a sample notification on launch |
| `CUB_TEST_LOGIN=1` / `=0` | Enables / disables the login item |

---

## Contributing

Contributions are welcome! Feel free to open an issue or submit a pull request.

1. Fork the repo
2. Create a feature branch (`git checkout -b feat/my-feature`)
3. Commit your changes
4. Open a Pull Request

---

## License

MIT — see [LICENSE](LICENSE) for details.
