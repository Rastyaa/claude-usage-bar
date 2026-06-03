# Claude Usage Bar

A macOS **menu bar app** (Swift 6 + SwiftUI/AppKit) that shows your Claude
Pro/Max usage in real time. The menu bar shows the 5-hour session percentage and
reset time; clicking the icon opens a dark popover with full usage detail.

```
🟠 75% · 1h 45m        ← menu bar
```

## How it works

Data comes from the same source `claudeusage-mcp` uses: the Anthropic OAuth
usage endpoint `https://api.anthropic.com/api/oauth/usage`, authenticated with
your Claude Code OAuth token read from the macOS Keychain
(`Claude Code-credentials`) or `~/.claude/.credentials.json`.

The app calls that endpoint directly with `URLSession` (no Node subprocess
needed) and polls every **60 seconds**.

- 🟢 0–60 % · 🟠 61–85 % · 🔴 86–100 %
- Notifications at 80 % and 95 % session usage (see caveat below)
- `LSUIElement` → menu-bar only, no Dock icon
- Optional **Launch at Login** toggle (SMAppService)

## Build & run

```bash
# Quick dev run (menu-bar item appears; notifications/login-item need the bundle)
swift run

# Build a proper .app bundle (recommended)
./make_app.sh
open ClaudeUsageBar.app
```

For Launch-at-Login and notifications to persist, install the bundle in a stable
location and launch it from there:

```bash
cp -R ClaudeUsageBar.app ~/Applications/
open ~/Applications/ClaudeUsageBar.app
```

## Files

| File | Role |
|------|------|
| `Sources/ClaudeUsageBar/main.swift` | Entry point |
| `Sources/ClaudeUsageBar/AppDelegate.swift` | `NSStatusItem` + `NSPopover` |
| `Sources/ClaudeUsageBar/UsageManager.swift` | Fetch, polling, model, notifications, login item |
| `Sources/ClaudeUsageBar/PopoverView.swift` | SwiftUI dark card |
| `Info.plist` | `LSUIElement`, bundle id |
| `make_app.sh` | Builds the release `.app` bundle |

## Notifications caveat

The 80 % / 95 % notification code is complete and correct, but macOS **suppresses
UserNotifications for ad-hoc-signed apps** (`codesign --sign -`). To get banners
you must sign the bundle with a stable identity (a Developer ID certificate, or a
trusted self-signed cert) so macOS shows the permission prompt and registers the
app. With the default ad-hoc signature the request is accepted but not displayed.

## Debug env flags

- `CUB_DEBUG_POPOVER=1` — render the popover in a standalone window (screenshots)
- `CUB_TEST_NOTIFY=1` — fire a sample notification on launch
- `CUB_TEST_LOGIN=1` / `CUB_TEST_LOGIN=0` — enable/disable the login item
