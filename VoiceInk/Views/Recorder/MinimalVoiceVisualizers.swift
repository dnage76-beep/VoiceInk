import SwiftUI

/// The Minimalist recorder is nothing but a voice animation now, so the
/// animation is a real choice. Three options, all full-width, all fed by the
/// same microphone meter; picked in Settings and stored here.
enum MinimalVoiceAnimation: String, CaseIterable, Identifiable {
    /// Flowing Siri-style wave: overlapping sines that swell with the voice.
    case wave
    /// Streaming history bars, Voice Memos style: what you just said scrolls
    /// away to the left while the newest sound lands at the right edge.
    case scroll
    /// A row of springy bars with a traveling ripple, loudest in the middle.
    case bars

    static let storageKey = "MinimalVoiceAnimation"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .wave: return String(localized: "Wave")
        case .scroll: return String(localized: "Scroll")
        case .bars: return String(localized: "Bars")
        }
    }

    var explanation: String {
        switch self {
        case .wave:
            return String(localized: "A flowing wave that swells as you speak.")
        case .scroll:
            return String(localized: "Your last few seconds stream past, newest at the right.")
        case .bars:
            return String(localized: "A row of bars ripples with your voice.")
        }
    }
}

// MARK: - Wave

/// Full-width Siri-style wave. Same engine as the Notch and Mini recorders'
/// visualizer, so the motion vocabulary matches, just stretched across the
/// whole pill instead of boxed into 76 points.
struct MinimalFlowingWave: View {
    let audioMeter: AudioMeter
    let color: Color
    let isActive: Bool

    @State private var engine = SiriWaveEngine()

    /// Stretched across the whole pill, raw meter values read nearly flat at
    /// normal speaking volume, so the wave gets a lift: a compressive curve
    /// plus gain, clamped so shouting cannot clip past the pill.
    private var boostedMeter: AudioMeter {
        let boosted = min(1.0, pow(max(audioMeter.averagePower, 0), 0.7) * 1.35)
        return AudioMeter(averagePower: boosted, peakPower: audioMeter.peakPower)
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { context in
            let frame = engine.frame(
                meter: boostedMeter,
                time: context.date.timeIntervalSinceReferenceDate,
                isActive: isActive
            )
            Canvas { canvasContext, size in
                SiriRippleRenderer.draw(
                    in: canvasContext,
                    size: size,
                    amplitude: frame.amplitude,
                    time: frame.time,
                    color: color
                )
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Scroll

/// Voice Memos-style streaming bars: the meter is sampled ~30 times a second
/// into a ring buffer, and the buffer is drawn newest-at-the-right, so speech
/// visibly streams away to the left as it is captured.
final class ScrollWaveEngine {
    private(set) var samples: [CGFloat] = []
    private var lastSampleTime: TimeInterval?
    private var level: CGFloat = 0

    private let sampleInterval: TimeInterval = 1.0 / 30.0

    func frame(meter: AudioMeter, time: TimeInterval, isActive: Bool, capacity: Int) -> [CGFloat] {
        let target: CGFloat = isActive ? CGFloat(max(meter.averagePower, 0)) : 0
        level += (target - level) * 0.4

        guard let last = lastSampleTime else {
            lastSampleTime = time
            return samples
        }

        if time - last >= sampleInterval {
            lastSampleTime = time
            // The curve spends more of the visible range on quiet speech,
            // where normal dictation actually sits.
            samples.append(pow(min(max(level, 0), 1), 0.7))
            if samples.count > capacity {
                samples.removeFirst(samples.count - capacity)
            }
        }

        return samples
    }

    func reset() {
        samples.removeAll()
        lastSampleTime = nil
        level = 0
    }
}

struct MinimalScrollWave: View {
    let audioMeter: AudioMeter
    let color: Color
    let isActive: Bool

    private let barWidth: CGFloat = 2
    private let barGap: CGFloat = 1.5
    /// Quiet moments still leave a visible seed, so the stream reads as a
    /// timeline rather than blinking in and out.
    private let floorHeight: CGFloat = 2

    @State private var engine = ScrollWaveEngine()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { context in
            Canvas { canvasContext, size in
                let capacity = Int(size.width / (barWidth + barGap)) + 1
                let samples = engine.frame(
                    meter: audioMeter,
                    time: context.date.timeIntervalSinceReferenceDate,
                    isActive: isActive,
                    capacity: capacity
                )

                let maxBarHeight = size.height - 2
                let midY = size.height / 2

                for (index, sample) in samples.enumerated() {
                    // Newest sample hugs the right edge.
                    let slot = samples.count - 1 - index
                    let x = size.width - barWidth - CGFloat(slot) * (barWidth + barGap)
                    if x < -barWidth { continue }

                    let height = max(floorHeight, sample * maxBarHeight)
                    let rect = CGRect(
                        x: x,
                        y: midY - height / 2,
                        width: barWidth,
                        height: height
                    )
                    canvasContext.fill(
                        Path(roundedRect: rect, cornerRadius: barWidth / 2),
                        with: .color(color.opacity(sample > 0.04 ? 0.95 : 0.45))
                    )
                }
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Bars

/// A full-width equalizer: bars ease toward the voice level while a slow
/// ripple travels across them, so the row undulates instead of stuttering.
/// A center bias keeps the loudest motion in the middle of the pill.
final class EqualizerEngine {
    private var lastTime: TimeInterval?
    private var phase: Double = 0
    private var level: CGFloat = 0

    private let attackTimeConstant: CGFloat = 0.05
    private let releaseTimeConstant: CGFloat = 0.26

    func frame(meter: AudioMeter, time: TimeInterval, isActive: Bool, count: Int) -> [CGFloat] {
        let dt = CGFloat(min(max(time - (lastTime ?? time), 0), 0.05))
        lastTime = time
        phase += Double(dt) * 5.2

        let target: CGFloat = isActive ? pow(CGFloat(max(meter.averagePower, 0)), 0.65) : 0
        let timeConstant = target > level ? attackTimeConstant : releaseTimeConstant
        if dt > 0 {
            level += (target - level) * (1 - exp(-dt / timeConstant))
        }

        let half = Double(count - 1) / 2
        return (0..<count).map { index in
            let travel = (sin(phase + Double(index) * 0.55) + 1) / 2
            let centerBias = 1 - (abs(Double(index) - half) / max(half, 1)) * 0.4
            // The idle floor breathes very slightly so the row feels alive
            // even in silence.
            let idleBreath = 0.05 + 0.02 * sin(phase * 0.4 + Double(index) * 0.8)
            let voiced = Double(level) * (0.30 + 0.70 * travel) * centerBias
            return CGFloat(max(idleBreath, voiced))
        }
    }
}

struct MinimalEqualizerBars: View {
    let audioMeter: AudioMeter
    let color: Color
    let isActive: Bool

    private let barWidth: CGFloat = 2.5
    private let barGap: CGFloat = 2.5

    @State private var engine = EqualizerEngine()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { context in
            Canvas { canvasContext, size in
                let count = max(Int(size.width / (barWidth + barGap)), 3)
                let heights = engine.frame(
                    meter: audioMeter,
                    time: context.date.timeIntervalSinceReferenceDate,
                    isActive: isActive,
                    count: count
                )

                let usedWidth = CGFloat(count) * barWidth + CGFloat(count - 1) * barGap
                let startX = (size.width - usedWidth) / 2
                let maxBarHeight = size.height - 2
                let midY = size.height / 2

                for (index, value) in heights.enumerated() {
                    let height = max(2, value * maxBarHeight)
                    let rect = CGRect(
                        x: startX + CGFloat(index) * (barWidth + barGap),
                        y: midY - height / 2,
                        width: barWidth,
                        height: height
                    )
                    canvasContext.fill(
                        Path(roundedRect: rect, cornerRadius: barWidth / 2),
                        with: .color(color.opacity(0.92))
                    )
                }
            }
        }
        .accessibilityHidden(true)
    }
}
