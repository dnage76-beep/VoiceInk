import SwiftUI

/// The words-per-minute dial.
///
/// Wispr shows a percentile here ("top 0.1%"), which needs everyone else's
/// numbers. VoiceInk is local-only, so the arc fills toward the user's own best
/// day instead: a number they set themselves and can actually beat.
struct InsightSpeedRing: View {
    let wordsPerMinute: Int?
    let personalBest: Int?
    /// Plays the sweep on first appearance only, so returning to the tab does
    /// not re-animate a number that has not changed.
    var playsEntrance: Bool = false

    @State private var progress: Double = 0

    private var target: Double {
        guard let wordsPerMinute, let personalBest, personalBest > 0 else { return 0 }
        return min(Double(wordsPerMinute) / Double(personalBest), 1)
    }

    /// True when this period's rate is the best ever recorded, which is worth
    /// saying out loud rather than showing an arc pinned silently at full.
    private var isPersonalBest: Bool {
        guard let wordsPerMinute, let personalBest else { return false }
        return wordsPerMinute >= personalBest
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(wordsPerMinute.map { String($0) } ?? "--")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(AppTheme.Text.primary)
                    .contentTransition(.numericText())
                    .monospacedDigit()

                HStack(spacing: 5) {
                    Text("WORDS PER MINUTE")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(0.6)
                        .foregroundStyle(AppTheme.Text.secondary)

                    InfoTip(
                        "Your speaking rate: words divided by time spent recording. "
                            + "The arc fills toward the fastest full day you have recorded."
                    )
                }
            }

            HStack {
                Spacer()
                ring
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(18)
        .background(DashboardInsightCardBackground(cornerRadius: 16))
        .onAppear {
            guard playsEntrance else {
                progress = target
                return
            }
            withAnimation(.easeOut(duration: 0.9).delay(0.15)) {
                progress = target
            }
        }
        .onChange(of: target) { _, newValue in
            withAnimation(.easeOut(duration: 0.5)) {
                progress = newValue
            }
        }
    }

    private var ring: some View {
        ZStack {
            // A half dial rather than a full circle: it reads as a gauge, and
            // it leaves the middle free for the label without crowding.
            //
            // Built by trimming a rotated Circle rather than with a custom
            // Shape: SwiftUI lays a Circle out inside its frame predictably,
            // where a hand-rolled arc path escaped the card's bounds.
            SpeedDial(progress: 1)
                .stroke(
                    AppTheme.Accent.primary.opacity(0.10),
                    style: StrokeStyle(lineWidth: 11, lineCap: .round)
                )

            SpeedDial(progress: progress)
                .stroke(
                    AppTheme.Accent.primary,
                    style: StrokeStyle(lineWidth: 11, lineCap: .round)
                )

        }
        // The dial is the top half of a circle, so it is drawn square and the
        // empty lower half is cropped away.
        .frame(width: 138, height: 138)
        .padding(.horizontal, 6)
        .frame(height: 75, alignment: .top)
        .clipped()
        // The caption sits in the dial's mouth, added after the crop so it is
        // not cut off by it.
        .overlay(alignment: .bottom) {
            VStack(spacing: 1) {
                Text(centerCaption)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppTheme.Text.secondary)

                Text(centerValue)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AppTheme.Text.primary)
                    .monospacedDigit()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var centerCaption: String {
        guard personalBest != nil else { return String(localized: "no record yet") }
        return isPersonalBest
            ? String(localized: "personal best") : String(localized: "your best")
    }

    private var centerValue: String {
        guard let personalBest else { return "--" }
        return String(personalBest)
    }

    private var accessibilityText: String {
        guard let wordsPerMinute else {
            return String(localized: "Words per minute not yet available")
        }
        guard let personalBest else {
            return String(format: String(localized: "%d words per minute"), wordsPerMinute)
        }
        return String(
            format: String(localized: "%d words per minute, personal best %d"),
            wordsPerMinute, personalBest
        )
    }
}

/// The upper half of a circle, filled left to right in proportion to progress.
///
/// A Circle inset by half its stroke width always draws inside its frame, so
/// the dial cannot spill past the card the way a hand-built arc path did. The
/// circle is rotated so trimming from 0 starts at the left end of the dial.
private struct SpeedDial: Shape {
    var progress: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let clamped = max(0, min(progress, 1))
        // The top half of the circle is the second quarter through the third,
        // i.e. trim fractions 0.5 through 1.0 after no rotation.
        return Circle()
            .trim(from: 0.5, to: 0.5 + 0.5 * clamped)
            .path(in: rect)
    }
}
