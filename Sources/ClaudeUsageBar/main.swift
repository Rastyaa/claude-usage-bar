import AppKit

// Entry point. The app runs as a menu-bar-only accessory (no Dock icon),
// configured via Info.plist LSUIElement and reinforced in AppDelegate.
let app = NSApplication.shared
// Top-level main.swift code runs on the main thread; assert main-actor
// isolation so we can build the @MainActor AppDelegate.
let delegate = MainActor.assumeIsolated { AppDelegate() }
app.delegate = delegate
app.run()
