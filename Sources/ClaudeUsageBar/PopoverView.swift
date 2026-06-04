import SwiftUI

// ─── Design tokens ────────────────────────────────────────────────────────────

private let bgMain   = Color(red: 0.08, green: 0.08, blue: 0.10)
private let bgCard   = Color(red: 0.14, green: 0.14, blue: 0.17)

private let clGreen  = Color(red: 0.20, green: 0.84, blue: 0.29)
private let clOrange = Color(red: 1.00, green: 0.62, blue: 0.04)
private let clRed    = Color(red: 1.00, green: 0.27, blue: 0.23)

private func usageColor(_ pct: Double) -> Color {
    if pct >= 86 { return clRed }
    if pct >= 61 { return clOrange }
    return clGreen
}

// ─── Progress bar ─────────────────────────────────────────────────────────────

private struct UsageBar: View {
    let percent: Double
    let active: Bool

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.07))
                if active {
                    Capsule()
                        .fill(LinearGradient(
                            colors: [usageColor(percent).opacity(0.65), usageColor(percent)],
                            startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(8, geo.size.width * min(percent, 100) / 100))
                }
            }
        }
        .frame(height: 6)
    }
}

// ─── Usage section card ───────────────────────────────────────────────────────

private struct UsageSection: View {
    let title: String
    let percent: Double
    let caption: String
    var active: Bool = true
    var inactiveMessage: String = "Start a conversation to begin tracking"

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.4))
                    .tracking(1.2)
                Spacer()
                Text(active ? "\(Int(percent.rounded()))%" : "0%")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(active ? usageColor(percent) : .white.opacity(0.2))
            }
            UsageBar(percent: percent, active: active)
            if active {
                Text(caption)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.35))
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 10))
                    Text(inactiveMessage)
                        .font(.system(size: 11))
                }
                .foregroundColor(.white.opacity(0.28))
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(bgCard))
    }
}

// ─── Stat cell ────────────────────────────────────────────────────────────────

private struct StatCell: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.white.opacity(0.35))
                .tracking(0.8)
            Text(value)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 12).fill(bgCard))
    }
}

// ─── Setup screen ─────────────────────────────────────────────────────────────
// Shown when no Claude Code OAuth token is found. The app reads usage from the
// credentials that Claude Code (CLI or VS Code extension) writes after sign-in,
// so the fix is to install one of those — not to log in on the web.

private struct SetupStep: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(number)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(clOrange)
                .frame(width: 20, height: 20)
                .background(Circle().fill(clOrange.opacity(0.15)))
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }
}

private struct SetupView: View {
    let onRetry: () -> Void

    private static let claudeCodeURL = URL(string: "https://claude.com/claude-code")!
    private static let extensionURL = URL(string: "https://marketplace.visualstudio.com/items?itemName=anthropic.claude-code")!

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 12)

            ZStack {
                Circle()
                    .fill(clOrange.opacity(0.12))
                    .frame(width: 64, height: 64)
                Image(systemName: "terminal.fill")
                    .font(.system(size: 26, weight: .medium))
                    .foregroundColor(clOrange)
            }
            .padding(.bottom, 16)

            Text("Connect Claude Code")
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.white)
                .padding(.bottom, 6)

            Text("Usage is read from Claude Code. Install it — or the VS Code extension — and sign in to start tracking.")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.45))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 22)
                .padding(.bottom, 18)

            VStack(alignment: .leading, spacing: 12) {
                SetupStep(number: 1, text: "Install Claude Code or the VS Code extension")
                SetupStep(number: 2, text: "Sign in with your Claude account")
                SetupStep(number: 3, text: "Click Try Again below")
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 12).fill(bgCard))
            .padding(.horizontal, 20)
            .padding(.bottom, 16)

            Button {
                NSWorkspace.shared.open(Self.claudeCodeURL)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.down.circle.fill")
                    Text("Install Claude Code")
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 10).fill(clOrange))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.bottom, 8)

            Button {
                NSWorkspace.shared.open(Self.extensionURL)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "puzzlepiece.extension.fill")
                    Text("Get VS Code Extension")
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.85))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 10).fill(bgCard))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.bottom, 14)

            Button("Try Again", action: onRetry)
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.4))

            Spacer(minLength: 12)
        }
        .frame(width: 280, height: 460)
        .background(bgMain)
    }
}

// ─── Popover root ─────────────────────────────────────────────────────────────

struct PopoverView: View {
    @ObservedObject var manager: UsageManager
    @State private var spinAngle: Double = 0

    private var usage: UsageData { manager.usage }

    var body: some View {
        if manager.tokenMissing {
            SetupView { Task { await manager.fetch() } }
        } else {
            VStack(alignment: .leading, spacing: 10) {

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
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white.opacity(manager.isLoading ? 0.8 : 0.45))
                            .rotationEffect(.degrees(spinAngle))
                            .onChange(of: manager.isLoading) { loading in
                                if loading {
                                    spinAngle = 0
                                    withAnimation(.linear(duration: 0.8).repeatForever(autoreverses: false)) {
                                        spinAngle = 360
                                    }
                                } else {
                                    withAnimation(.none) { spinAngle = 0 }
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 4)

                // Session
                UsageSection(
                    title: "SESSION",
                    percent: usage.sessionPercent,
                    caption: "Resets in \(usage.sessionResetIn)",
                    active: usage.sessionActive,
                    inactiveMessage: "Start a conversation to begin your session"
                )

                // Weekly
                UsageSection(
                    title: "WEEKLY",
                    percent: usage.weeklyPercent,
                    caption: "Resets \(usage.weeklyResetsAt)",
                    active: usage.weeklyActive,
                    inactiveMessage: "No weekly usage recorded yet"
                )

                // Stats row
                HStack(spacing: 8) {
                    StatCell(label: "DAILY ROUTINES",
                             value: "\(usage.dailyRoutines) / \(usage.dailyRoutinesMax)")
                    StatCell(label: "USAGE CREDITS",
                             value: usage.usageCredits ? "ON" : "OFF")
                }

                // Launch at login
                HStack {
                    Text("LAUNCH AT LOGIN")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.4))
                        .tracking(0.8)
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { manager.launchAtLogin },
                        set: { manager.setLaunchAtLogin($0) }
                    ))
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .tint(clGreen)
                    .labelsHidden()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(RoundedRectangle(cornerRadius: 12).fill(bgCard))

                Spacer()

                // Error
                if let error = manager.errorMessage {
                    Text(error)
                        .font(.system(size: 10))
                        .foregroundColor(clRed.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Footer
                HStack {
                    Text("Updated \(usage.lastUpdated)")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.28))
                    Spacer()
                    Button("Quit") { NSApplication.shared.terminate(nil) }
                        .buttonStyle(.plain)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.55))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.08)))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 16)
            .frame(width: 280, height: 460)
            .background(bgMain)
        }
    }
}
