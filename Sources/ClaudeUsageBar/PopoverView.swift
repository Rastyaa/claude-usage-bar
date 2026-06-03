import SwiftUI

// ─── Color helpers ───────────────────────────────────────────────────────────

private func usageColor(_ percent: Double) -> Color {
    if percent >= 86 { return Color(red: 0.93, green: 0.27, blue: 0.27) }   // red
    if percent >= 61 { return Color(red: 0.96, green: 0.62, blue: 0.10) }   // orange
    return Color(red: 0.30, green: 0.78, blue: 0.45)                        // green
}

// ─── Progress bar ────────────────────────────────────────────────────────────

private struct UsageBar: View {
    let percent: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.white.opacity(0.08))
                RoundedRectangle(cornerRadius: 5)
                    .fill(usageColor(percent))
                    .frame(width: max(6, geo.size.width * min(percent, 100) / 100))
            }
        }
        .frame(height: 8)
    }
}

// ─── A labelled section (SESSION / WEEKLY) ───────────────────────────────────

private struct UsageSection: View {
    let title: String
    let percent: Double
    let caption: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                    .tracking(0.8)
                Spacer()
                Text("\(Int(percent.rounded()))%")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(usageColor(percent))
            }
            UsageBar(percent: percent)
            Text(caption)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.45))
        }
    }
}

// ─── Sign-in screen (shown when no Claude credentials are found) ─────────────

private struct SignInView: View {
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Image(systemName: "person.badge.key.fill")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(.white.opacity(0.25))
                .padding(.bottom, 20)

            Text("Not signed in")
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.white)
                .padding(.bottom, 8)

            Text("Claude Code credentials not found on this Mac.\nSign in at claude.ai, then click Try Again.")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 24)
                .padding(.bottom, 28)

            Button {
                NSWorkspace.shared.open(URL(string: "https://claude.ai")!)
            } label: {
                Text("Open claude.ai")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(red: 0.96, green: 0.62, blue: 0.10)))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 24)
            .padding(.bottom, 10)

            Button("Try Again", action: onRetry)
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
                .padding(.bottom, 4)

            Spacer()
        }
        .frame(width: 280, height: 460)
        .background(Color(red: 0.10, green: 0.10, blue: 0.12))
    }
}

// ─── Popover root ────────────────────────────────────────────────────────────

struct PopoverView: View {
    @ObservedObject var manager: UsageManager

    private var usage: UsageData { manager.usage }

    var body: some View {
        if manager.tokenMissing {
            SignInView {
                Task { await manager.fetch() }
            }
        } else {
        VStack(alignment: .leading, spacing: 14) {

            // Header
            HStack {
                Text("Claude Usage")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Button {
                    Task { await manager.fetch() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                        .rotationEffect(.degrees(manager.isLoading ? 360 : 0))
                        .animation(manager.isLoading
                            ? .linear(duration: 0.8).repeatForever(autoreverses: false)
                            : .default, value: manager.isLoading)
                }
                .buttonStyle(.plain)
            }

            Divider().overlay(Color.white.opacity(0.1))

            UsageSection(title: "SESSION",
                         percent: usage.sessionPercent,
                         caption: "Resets in \(usage.sessionResetIn)")

            Divider().overlay(Color.white.opacity(0.1))

            UsageSection(title: "WEEKLY",
                         percent: usage.weeklyPercent,
                         caption: "Resets \(usage.weeklyResetsAt)")

            Divider().overlay(Color.white.opacity(0.1))

            // Daily routines / credits
            VStack(spacing: 8) {
                rowItem(label: "DAILY ROUTINES",
                        value: "\(usage.dailyRoutines) / \(usage.dailyRoutinesMax)")
                rowItem(label: "USAGE CREDITS",
                        value: usage.usageCredits ? "ON" : "OFF")
            }

            Divider().overlay(Color.white.opacity(0.1))

            // Launch at login
            Toggle(isOn: Binding(
                get: { manager.launchAtLogin },
                set: { manager.setLaunchAtLogin($0) }
            )) {
                Text("LAUNCH AT LOGIN")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                    .tracking(0.8)
            }
            .toggleStyle(.switch)
            .controlSize(.mini)
            .tint(Color(red: 0.30, green: 0.78, blue: 0.45))

            Divider().overlay(Color.white.opacity(0.1))

            // Footer
            HStack {
                Text("Last updated: \(usage.lastUpdated)")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.4))
                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white.opacity(0.08)))
            }

            if let error = manager.errorMessage {
                Text(error)
                    .font(.system(size: 10))
                    .foregroundColor(Color(red: 0.95, green: 0.5, blue: 0.5))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 24)
        .padding(.bottom, 16)
        .frame(width: 280, height: 460)
        .background(Color(red: 0.10, green: 0.10, blue: 0.12))
        } // else
    }

    private func rowItem(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.5))
                .tracking(0.8)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.85))
        }
    }
}
