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
            // Top padding clears the ink band and the longest drip beneath it.
            .padding(.top, 66)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity, minHeight: 160, alignment: .leading)
            .background(DashboardHeroBackground())
            .clipShape(RoundedRectangle(cornerRadius: DashboardLayout.cardCornerRadius, style: .continuous))
    }

    private var lockedInsightsPrompt: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                // A single drop: the pour is unreadable at this size, one
                // drop still carries the mark.
                InkDropShape()
                    .fill(DashboardHeroPalette.ink)
                    .frame(width: 11, height: 26)
                    .alignmentGuide(.firstTextBaseline) { $0.height }
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

            ProgressView(value: min(max(unlockProgress, 0), 1))
                .progressViewStyle(.linear)
                .tint(DashboardHeroPalette.ink)
                .frame(maxWidth: 420)

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
        ZStack(alignment: .top) {
            DashboardInsightCardBackground()

            // The one place the app draws literal ink. Static and flat, in the
            // style of a poured-ink illustration.
            InkDripShape()
                .fill(DashboardHeroPalette.ink)
                .allowsHitTesting(false)
        }
        .clipShape(RoundedRectangle(cornerRadius: DashboardLayout.cardCornerRadius, style: .continuous))
    }
}

private enum DashboardHeroPalette {
    static let ink = AppTheme.Accent.primary
    static let headline = AppTheme.Text.primary
    static let subtext = AppTheme.Text.secondary
}
