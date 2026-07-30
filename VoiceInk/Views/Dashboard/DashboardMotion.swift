import SwiftUI

/// Motion helpers for the dashboard landing page. Strictly monochrome-neutral:
/// nothing here draws a color, so the page's clean light look stays untouched
/// while it gains a little life on load.

/// The entrance plays once per app session; returning to the tab renders
/// settled immediately, so the animation stays a moment rather than a toll.
/// Read from View inits, which are not MainActor-isolated, so this stays a
/// plain static; it is only ever touched from SwiftUI view construction.
enum DashboardEntrance {
    nonisolated(unsafe) static var hasPlayed = false
}

private struct EntranceReveal: ViewModifier {
    let delay: Double
    let play: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealed = false

    private var animatesMotion: Bool { play && !reduceMotion }

    func body(content: Content) -> some View {
        content
            .opacity(revealed ? 1 : 0)
            .offset(y: revealed || !animatesMotion ? 0 : 10)
            .onAppear {
                let animation: Animation =
                    animatesMotion
                    ? .spring(response: 0.5, dampingFraction: 0.9).delay(delay)
                    : .easeOut(duration: 0.15)
                withAnimation(animation) {
                    revealed = true
                }
            }
    }
}

extension View {
    /// Quiet staggered page-load reveal: a short rise and fade, nothing more.
    func entranceReveal(delay: Double, play: Bool) -> some View {
        modifier(EntranceReveal(delay: delay, play: play))
    }
}

/// Text that counts up to its value, formatting every intermediate frame, so
/// "1.8K" rolls through real values instead of jump-cutting. Also animates
/// when the target changes, which makes switching the insights period feel
/// mechanical in the good way: flip the period, watch the numbers re-settle.
private struct CountUpModifier: AnimatableModifier {
    var value: Double
    let format: (Double) -> String

    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    func body(content: Content) -> some View {
        Text(format(value))
    }
}

struct CountUpText: View {
    let target: Double
    let format: (Double) -> String
    let delay: Double
    let play: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown: Double = 0

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .modifier(CountUpModifier(value: shown, format: format))
            .onAppear {
                guard play, !reduceMotion else {
                    shown = target
                    return
                }
                withAnimation(.easeOut(duration: 0.9).delay(delay)) {
                    shown = target
                }
            }
            .onChange(of: target) { _, newTarget in
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.5)) {
                    shown = newTarget
                }
            }
    }
}
