import Foundation
import SwiftUI

/// Shown on the dashboard only while insights are still locked, so this card
/// has one state: the unlock prompt.
struct DashboardHeroCard: View {
    var unlockProgress: Double = 0
    var unlockMinutesRemaining: Int = 0

    var body: some View {
        lockedInsightsPrompt
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity, minHeight: 160, alignment: .leading)
            .background(DashboardHeroBackground())
            .clipShape(RoundedRectangle(cornerRadius: DashboardLayout.cardCornerRadius, style: .continuous))
    }

    private var lockedInsightsPrompt: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.black.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(Color.black.opacity(0.10), lineWidth: 1)
                        )

                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(DashboardHeroPalette.accent)
                }
                .frame(width: 36, height: 36)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Insights unlock as you dictate")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(DashboardHeroPalette.headline)

                    Text(unlockDetailText)
                        .font(.system(size: 13))
                        .foregroundStyle(DashboardHeroPalette.subtext)
                }
            }

            // Drawn by hand because the system linear ProgressView keeps the
            // system accent color on macOS no matter what tint says, and this
            // card is strictly black-and-white.
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(DashboardHeroPalette.accent.opacity(0.14))

                    Capsule(style: .continuous)
                        .fill(DashboardHeroPalette.accent)
                        .frame(width: geometry.size.width * min(max(unlockProgress, 0), 1))
                }
            }
            .frame(maxWidth: 420)
            .frame(height: 5)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Insights unlock progress"))
            .accessibilityValue(Text("\(Int((min(max(unlockProgress, 0), 1) * 100).rounded())) percent"))

            Text("Coming up: time saved vs typing, words per day, your peak dictation hours, and per-model speed and accuracy.")
                .font(.system(size: 13))
                .foregroundStyle(DashboardHeroPalette.subtext)
                .frame(maxWidth: 540, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var unlockDetailText: String {
        if unlockMinutesRemaining > 0 {
            return String(
                format: String(localized: "About %d min of dictation to go."),
                unlockMinutesRemaining
            )
        }
        return String(localized: "Almost there. Keep dictating.")
    }
}

private struct DashboardHeroBackground: View {
    var body: some View {
        // Derek's ink-wash artwork: white marble on the left where the copy
        // sits, black ink swirling in from the right edge. The artwork is held
        // back against a white card so it reads as a watermark behind the
        // text rather than competing with it, and the darkest swirls on the
        // right stop swallowing the line that overruns them.
        ZStack {
            Color(nsColor: .controlBackgroundColor)

            Image("hero-bg")
                .resizable()
                .scaledToFill()
                .opacity(0.42)
        }
        .clipShape(RoundedRectangle(cornerRadius: DashboardLayout.cardCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DashboardLayout.cardCornerRadius, style: .continuous)
                .stroke(Color.black.opacity(0.10), lineWidth: 1)
        )
        .allowsHitTesting(false)
    }
}

/// The artwork is always light, so these are fixed rather than pulled from
/// AppTheme, which follows the window appearance. Ink black is the accent:
/// the card stays black-and-white like the artwork.
private enum DashboardHeroPalette {
    static let accent = Color(red: 0.10, green: 0.10, blue: 0.09)
    static let headline = Color(red: 0.10, green: 0.10, blue: 0.09)
    static let subtext = Color(red: 0.10, green: 0.10, blue: 0.09).opacity(0.62)
}
