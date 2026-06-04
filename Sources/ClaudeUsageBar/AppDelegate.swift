import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private let manager = UsageManager()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu-bar-only: no Dock icon. (Info.plist LSUIElement covers the
        // bundled app; this reinforces it for `swift run`.)
        NSApp.setActivationPolicy(.accessory)

        setupStatusItem()
        setupPopover()

        manager.onUpdate = { [weak self] data in
            self?.statusItem.button?.title = data.menuBarTitle
        }
        manager.start()

        // Debug aid: exercise the login-item registration and log the result.
        if let v = ProcessInfo.processInfo.environment["CUB_TEST_LOGIN"] {
            let result = manager.setLaunchAtLogin(v != "0")
            NSLog("ClaudeUsageBar login-item enabled -> %@", String(result))
        }

        // Debug aid: fire a sample notification (disabled — requires Developer ID signing).
        // if ProcessInfo.processInfo.environment["CUB_TEST_NOTIFY"] != nil {
        //     DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
        //         self?.manager.sendTestNotification()
        //     }
        // }

        // Debug aid: render the popover UI in a fixed standalone window so it
        // can be screenshotted regardless of the notch / menu-bar crowding.
        if ProcessInfo.processInfo.environment["CUB_DEBUG_POPOVER"] != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
                self?.showDebugWindow()
            }
        }
    }

    private var debugWindow: NSWindow?

    private func showDebugWindow() {
        let host = NSHostingController(rootView: PopoverView(manager: manager))
        let win = NSWindow(contentViewController: host)
        win.styleMask = [.titled, .closable]
        win.title = "ClaudeUsageBar (debug)"
        win.setContentSize(NSSize(width: 280, height: 380))
        win.setFrameOrigin(NSPoint(x: 200, y: 400))
        win.makeKeyAndOrderFront(nil)
        win.level = .floating
        debugWindow = win
    }

    func applicationWillTerminate(_ notification: Notification) {
        manager.stop()
    }

    // MARK: Status item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem.button else { return }
        button.title = "◌ …"
        button.font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .medium)
        button.action = #selector(togglePopover)
        button.target = self
    }

    // MARK: Popover

    private func setupPopover() {
        popover.behavior = .transient
        popover.animates = true
        let host = NSHostingController(rootView: PopoverView(manager: manager))
        // Fix explicit size so NSPopover doesn't auto-position above the menu bar.
        host.view.setFrameSize(NSSize(width: 280, height: 460))
        popover.contentSize = NSSize(width: 280, height: 460)
        popover.contentViewController = host
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            // Nudge the popover window down so it doesn't overlap the menu bar.
            DispatchQueue.main.async {
                if let win = self.popover.contentViewController?.view.window {
                    var f = win.frame
                    f.origin.y -= 8
                    win.setFrameOrigin(f.origin)
                }
            }
            popover.contentViewController?.view.window?.makeKey()
            Task { await manager.fetch() }
        }
    }
}
