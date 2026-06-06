import Foundation
import ServiceManagement
// import UserNotifications — disabled, see MARK: Notifications

// ─── Raw API shape ───────────────────────────────────────────────────────────
// Mirrors https://api.anthropic.com/api/oauth/usage (the same endpoint that
// claudeusage-mcp wraps). Only the fields we display are decoded.

private struct RawUsageWindow: Decodable {
    let utilization: Double
    let resets_at: String?
}

private struct RawExtraUsage: Decodable {
    let is_enabled: Bool?
}

private struct RawUsageResponse: Decodable {
    let five_hour: RawUsageWindow
    let seven_day: RawUsageWindow
    let extra_usage: RawExtraUsage?
}

// ─── Display model ───────────────────────────────────────────────────────────

struct UsageData {
    var sessionPercent: Double      // 61.0
    var sessionResetIn: String      // "2h 8m"
    var sessionActive: Bool         // false when resets_at is nil (no active session)
    var weeklyPercent: Double       // 14.0
    var weeklyResetsAt: String      // "Sat 9:00 AM"
    var weeklyActive: Bool          // false when resets_at is nil
    var dailyRoutines: Int          // 0
    var dailyRoutinesMax: Int       // 5
    var usageCredits: Bool          // false
    var lastUpdated: String         // "just now"

    /// Shown before the first successful fetch.
    static let placeholder = UsageData(
        sessionPercent: 0, sessionResetIn: "—", sessionActive: false,
        weeklyPercent: 0, weeklyResetsAt: "—", weeklyActive: false,
        dailyRoutines: 0, dailyRoutinesMax: 5,
        usageCredits: false, lastUpdated: "never"
    )

    /// Fallback so the UI is testable even when the live fetch fails.
    static let mock = UsageData(
        sessionPercent: 61, sessionResetIn: "2h 8m", sessionActive: true,
        weeklyPercent: 14, weeklyResetsAt: "Sat 9:00 AM", weeklyActive: true,
        dailyRoutines: 0, dailyRoutinesMax: 5,
        usageCredits: false, lastUpdated: "mock data"
    )

    /// 🟢 0–60 · 🟠 61–85 · 🔴 86–100
    var emoji: String {
        if sessionPercent >= 86 { return "🔴" }
        if sessionPercent >= 61 { return "🟠" }
        return "🟢"
    }

    /// e.g. "🟠 61% · 2h 8m" or "○ No session" when inactive
    var menuBarTitle: String {
        guard sessionActive else { return "○ No session" }
        return "\(emoji) \(Int(sessionPercent.rounded()))% · \(sessionResetIn)"
    }
}

// ─── Manager ─────────────────────────────────────────────────────────────────

@MainActor
final class UsageManager: ObservableObject {

    @Published private(set) var usage: UsageData = .placeholder
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var tokenMissing = false
    @Published private(set) var tokenExpired = false

    /// Called on the main actor after every state change with the menu-bar
    /// title so the AppDelegate can refresh the status item.
    var onUpdate: ((String) -> Void)?

    /// Menu-bar text that reflects auth state, so it never shows stale usage
    /// while the token is missing or expired.
    private var statusTitle: String {
        if tokenMissing { return "○ Sign in" }
        if tokenExpired { return "⚠ Expired" }
        return usage.menuBarTitle
    }

    private let endpoint = URL(string: "https://api.anthropic.com/api/oauth/usage")!
    private var timer: Timer?
    private var countdownTimer: Timer?
    private var lastFetch: Date?
    // Store raw reset dates so we can recompute display strings without re-fetching.
    private var sessionResetsAt: Date?
    private var weeklyResetsAt: Date?

    // private var notified80 = false  // disabled, see MARK: Notifications
    // private var notified95 = false

    // MARK: Lifecycle

    func start() {
        // requestNotificationAuthorization() — disabled, see MARK: Notifications below
        Task { await fetch() }
        // Fetch fresh data from the API every 2 minutes.
        timer = Timer.scheduledTimer(withTimeInterval: 120, repeats: true) { [weak self] _ in
            Task { await self?.fetch() }
        }
        // Update the countdown display every 60s without hitting the API.
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.refreshCountdown()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        countdownTimer?.invalidate()
        countdownTimer = nil
    }

    /// Recomputes the reset-time strings and menu bar title from cached dates.
    private func refreshCountdown() {
        guard lastFetch != nil else { return }
        if let d = sessionResetsAt {
            usage.sessionResetIn = Self.relativeUntil(d)
        }
        if let d = weeklyResetsAt {
            usage.weeklyResetsAt = Self.absoluteReset(d)
        }
        usage.lastUpdated = lastFetch.map { Self.relativeSince($0) } ?? usage.lastUpdated
        onUpdate?(statusTitle)
    }

    // MARK: Launch at login

    /// Whether the app is registered to launch at login.
    var launchAtLogin: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Toggles the login-item registration. Returns the resulting state.
    @discardableResult
    func setLaunchAtLogin(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
        } catch {
            errorMessage = "Login item: \(error.localizedDescription)"
        }
        objectWillChange.send()
        return launchAtLogin
    }

    // MARK: Fetch

    func fetch() async {
        isLoading = true
        defer { isLoading = false; publish() }

        guard let token = Self.readOAuthToken() else {
            // Credentials present but unreadable (e.g. Keychain locked) is an
            // expired/locked state, not a sign-out — keep them apart.
            if Self.credentialsExist() {
                tokenExpired = true
                tokenMissing = false
            } else {
                tokenMissing = true
                tokenExpired = false
            }
            errorMessage = nil
            return
        }
        tokenMissing = false
        tokenExpired = false

        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.setValue("ClaudeUsageBar/1.0", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                errorMessage = "No HTTP response"; return
            }
            guard http.statusCode == 200 else {
                switch http.statusCode {
                case 429:
                    errorMessage = "Rate limited — will retry automatically"
                    if usage.lastUpdated == "never" { usage = .mock }
                case 401:
                    // The token expired — Claude Code refreshes it on next use.
                    tokenExpired = true
                    errorMessage = nil
                default:
                    errorMessage = "API error \(http.statusCode)"
                    if usage.lastUpdated == "never" { usage = .mock }
                }
                return
            }
            let raw = try JSONDecoder().decode(RawUsageResponse.self, from: data)
            sessionResetsAt = Self.parseDate(raw.five_hour.resets_at)
            weeklyResetsAt  = Self.parseDate(raw.seven_day.resets_at)
            usage = Self.map(raw)
            lastFetch = Date()
            errorMessage = nil
            // checkNotifications(usage.sessionPercent) — disabled, see MARK: Notifications below
        } catch {
            errorMessage = error.localizedDescription
            if usage.lastUpdated == "never" { usage = .mock }
        }
    }

    private func publish() {
        if let last = lastFetch {
            usage.lastUpdated = Self.relativeSince(last)
        }
        onUpdate?(statusTitle)
    }

    // MARK: Mapping

    private static func map(_ raw: RawUsageResponse) -> UsageData {
        // API returns utilization as 0.0–1.0 fraction; convert to 0–100 for display.
        UsageData(
            sessionPercent: raw.five_hour.utilization * 100,
            sessionResetIn: relativeUntil(raw.five_hour.resets_at),
            sessionActive: parseDate(raw.five_hour.resets_at).map { $0.timeIntervalSinceNow > 0 } ?? false,
            weeklyPercent: raw.seven_day.utilization * 100,
            weeklyResetsAt: absoluteReset(raw.seven_day.resets_at),
            weeklyActive: parseDate(raw.seven_day.resets_at).map { $0.timeIntervalSinceNow > 0 } ?? false,
            dailyRoutines: 0,
            dailyRoutinesMax: 5,
            usageCredits: raw.extra_usage?.is_enabled ?? false,
            lastUpdated: "just now"
        )
    }

    // MARK: Date helpers

    /// Parses ISO-8601 timestamps, tolerating fractional seconds of any length
    /// (the API emits microseconds: "...:00.377755+00:00").
    private static func parseDate(_ string: String?) -> Date? {
        guard var s = string else { return nil }
        if let regex = try? NSRegularExpression(pattern: "\\.[0-9]+") {
            s = regex.stringByReplacingMatches(
                in: s, range: NSRange(s.startIndex..., in: s), withTemplate: "")
        }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        return iso.date(from: s)
    }

    /// "2h 8m" / "47m" — time remaining until the given timestamp string.
    private static func relativeUntil(_ string: String?) -> String {
        guard let date = parseDate(string) else { return "—" }
        return relativeUntil(date)
    }

    /// "2h 8m" / "47m" — time remaining until a Date.
    static func relativeUntil(_ date: Date) -> String {
        let mins = max(0, Int(date.timeIntervalSinceNow / 60))
        let h = mins / 60, m = mins % 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }

    /// "Sat 9:00 AM" — absolute weekday + time of the reset (from string).
    private static func absoluteReset(_ string: String?) -> String {
        guard let date = parseDate(string) else { return "—" }
        return absoluteReset(date)
    }

    /// "Sat 9:00 AM" — absolute weekday + time of the reset (from Date).
    static func absoluteReset(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US")
        f.dateFormat = "EEE h:mm a"
        return f.string(from: date)
    }

    /// "just now" / "2m ago" / "1h 30m ago" — how long since the last successful fetch.
    private static func relativeSince(_ date: Date) -> String {
        let secs = Int(-date.timeIntervalSinceNow)
        if secs < 10 { return "just now" }
        if secs < 60 { return "\(secs)s ago" }
        let mins = secs / 60
        if mins < 60 { return "\(mins)m ago" }
        let h = mins / 60, m = mins % 60
        return m > 0 ? "\(h)h \(m)m ago" : "\(h)h ago"
    }

    // MARK: Token

    /// Reads the Claude Code OAuth access token from the credentials file or
    /// the macOS Keychain (same locations claudeusage-mcp uses).
    private static func readOAuthToken() -> String? {
        for path in credentialFilePaths() {
            if let data = FileManager.default.contents(atPath: path),
               let token = parseToken(data) {
                return token
            }
        }
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        task.arguments = ["find-generic-password", "-s", "Claude Code-credentials", "-w"]
        let out = Pipe()
        task.standardOutput = out
        task.standardError = Pipe()
        guard (try? task.run()) != nil else { return nil }
        task.waitUntilExit()
        guard task.terminationStatus == 0 else { return nil }
        return parseToken(out.fileHandleForReading.readDataToEndOfFile())
    }

    /// Candidate `.credentials.json` locations, in priority order. Honors
    /// `CLAUDE_CONFIG_DIR` — the same override Claude Code itself respects —
    /// before falling back to the default `~/.claude` directory.
    private static func credentialFilePaths() -> [String] {
        var paths: [String] = []
        if let dir = ProcessInfo.processInfo.environment["CLAUDE_CONFIG_DIR"],
           !dir.isEmpty {
            paths.append((dir as NSString).expandingTildeInPath + "/.credentials.json")
        }
        paths.append(NSHomeDirectory() + "/.claude/.credentials.json")
        return paths
    }

    /// True when a credentials file or the Keychain item exists, even if the
    /// token itself can't currently be read (e.g. Keychain locked, expired).
    /// Distinguishes "expired / locked" from "never signed in". Reads only the
    /// item's metadata (no `-w`), so it never triggers an unlock prompt.
    private static func credentialsExist() -> Bool {
        for path in credentialFilePaths() where FileManager.default.fileExists(atPath: path) {
            return true
        }
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        task.arguments = ["find-generic-password", "-s", "Claude Code-credentials"]
        task.standardOutput = Pipe()
        task.standardError = Pipe()
        guard (try? task.run()) != nil else { return false }
        task.waitUntilExit()
        return task.terminationStatus == 0
    }

    private static func parseToken(_ data: Data) -> String? {
        guard
            let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let oauth = obj["claudeAiOauth"] as? [String: Any],
            let token = oauth["accessToken"] as? String, !token.isEmpty
        else { return nil }
        return token
    }

    // MARK: Notifications
    //
    // ⚠️  DISABLED — requires a Developer ID certificate to work on macOS.
    //
    // macOS suppresses UserNotifications for ad-hoc-signed apps (codesign --sign -).
    // To enable: sign the app with a Developer ID certificate (Apple Developer Program,
    // $99/year), then uncomment the two call sites above and re-enable the methods below.
    //
    // Contributors with a Developer ID can re-enable this by:
    //   1. Uncommenting `requestNotificationAuthorization()` in start()
    //   2. Uncommenting `checkNotifications(...)` in fetch()
    //   3. Signing with: codesign --force --deep --sign "Developer ID Application: ..." ClaudeUsageBar.app

//    private func requestNotificationAuthorization() {
//        guard Bundle.main.bundleIdentifier != nil else { return }
//        UNUserNotificationCenter.current()
//            .requestAuthorization(options: [.alert, .sound]) { granted, error in
//                if let error { NSLog("ClaudeUsageBar notif auth: %@", error.localizedDescription) }
//                else if !granted { NSLog("ClaudeUsageBar: notifications not permitted") }
//            }
//    }
//
//    private func checkNotifications(_ pct: Double) {
//        if pct < 80 {
//            notified80 = false
//            notified95 = false
//        } else if pct < 95 {
//            notified95 = false
//            if !notified80 {
//                notify(title: "Claude usage at \(Int(pct))%",
//                       body: "You've used 80% of your 5-hour session.")
//                notified80 = true
//            }
//        } else {
//            notified80 = true
//            if !notified95 {
//                notify(title: "Claude usage at \(Int(pct))%",
//                       body: "You're nearly at your session limit.")
//                notified95 = true
//            }
//        }
//    }
//
//    func sendTestNotification() {
//        notify(title: "Claude usage at 80%",
//               body: "Notification test — thresholds 80% and 95% are wired up.")
//    }
//
//    private func notify(title: String, body: String) {
//        guard Bundle.main.bundleIdentifier != nil else { return }
//        let content = UNMutableNotificationContent()
//        content.title = title
//        content.body = body
//        content.sound = .default
//        let request = UNNotificationRequest(
//            identifier: UUID().uuidString, content: content, trigger: nil)
//        UNUserNotificationCenter.current().add(request) { error in
//            if let error { NSLog("ClaudeUsageBar notif: %@", error.localizedDescription) }
//        }
//    }
}
