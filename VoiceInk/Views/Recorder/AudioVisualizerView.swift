import SwiftUI

// Faithful port of SwiftSiriWaveformView
// (https://github.com/alankarmisra/SwiftSiriWaveformView, MIT, (c) 2015 Alankar Misra),
// itself a Swift adaptation of SCSiriWaveformView (MIT, (c) Stefan Ceriu).
// Algorithm, parameters, and usage match the original: amplitude tracks the
// microphone meter directly, so the wave ripples gently on ambient sound and
// swells with speech, exactly like the classic Siri waveform.
struct AudioVisualizer: View {
    let audioMeter: AudioMeter
    let color: Color
    let isActive: Bool

    // Original SwiftSiriWaveformView defaults.
    private let frequency: CGFloat = 1.5
    private let idleAmplitude: CGFloat = 0.01
    private let phaseShift: CGFloat = -0.15  // per frame, as in the original
    private let numberOfWaves = 6
    private let primaryLineWidth: CGFloat = 1.5
    private let secondaryLineWidth: CGFloat = 0.5

    private let waveWidth: CGFloat = 76
    private let waveHeight: CGFloat = 28

    @State private var engine = SiriWaveEngine()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { context in
            let state = engine.frame(
                meter: audioMeter,
                time: context.date.timeIntervalSinceReferenceDate,
                isActive: isActive,
                phaseShift: phaseShift,
                idleAmplitude: idleAmplitude
            )
            Canvas { canvasContext, size in
                let mid = size.width / 2
                let maxAmplitude = size.height / 2 - primaryLineWidth

                for waveIndex in 0..<numberOfWaves {
                    let progress = 1.0 - CGFloat(waveIndex) / CGFloat(numberOfWaves)
                    let normedAmplitude = (1.5 * progress - 0.8) * CGFloat(state.amplitude)
                    let opacityMultiplier = min(1.0, (progress / 3.0 * 2.0) + (1.0 / 3.0))

                    var path = Path()
                    var x: CGFloat = 0
                    while x <= size.width {
                        // Parabolic scaling pins the wave at both edges.
                        let scaling = -pow(1 / mid * (x - mid), 2) + 1
                        let y = scaling * maxAmplitude * normedAmplitude
                            * sin(2 * .pi * frequency * (x / size.width) + CGFloat(state.phase))
                            + size.height / 2
                        if x == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                        x += 1
                    }

                    canvasContext.stroke(
                        path,
                        with: .color(color.opacity(Double(opacityMultiplier))),
                        lineWidth: waveIndex == 0 ? primaryLineWidth : secondaryLineWidth
                    )
                }
            }
        }
        .frame(width: waveWidth, height: waveHeight)
    }
}

// Advances the wave phase each frame and eases amplitude toward the live
// meter value, mirroring how the original demo feeds SwiftSiriWaveformView.
final class SiriWaveEngine {
    struct WaveState {
        var amplitude: Double
        var phase: Double
    }

    private var lastTime: TimeInterval?
    private var phase: Double = 0
    private var amplitude: Double = 0

    func frame(meter: AudioMeter, time: TimeInterval, isActive: Bool, phaseShift: CGFloat, idleAmplitude: CGFloat) -> WaveState {
        let dt = min(max(time - (lastTime ?? time), 0), 0.05)
        lastTime = time

        // Original advances phase once per drawn frame; scale by dt * 60 so
        // the speed is identical at any refresh rate.
        phase += Double(phaseShift) * dt * 60

        // Feed the meter straight in (it is already EMA-smoothed upstream);
        // a light ease here just removes frame-to-frame stair-steps.
        let target = isActive ? max(meter.averagePower, Double(idleAmplitude)) : Double(idleAmplitude)
        amplitude += (target - amplitude) * (dt > 0 ? 1 - exp(-dt / 0.1) : 1)

        return WaveState(amplitude: amplitude, phase: phase)
    }
}

// Idle recorder (no audio input yet): the same wave at idle amplitude,
// still gently moving so the transition into recording is seamless.
struct StaticVisualizer: View {
    let color: Color

    var body: some View {
        AudioVisualizer(
            audioMeter: AudioMeter(averagePower: 0, peakPower: 0),
            color: color.opacity(0.6),
            isActive: false
        )
    }
}

// MARK: - Processing Status Display

struct ProcessingStatusDisplay: View {
    enum Mode {
        case transcribing
        case enhancing
    }

    let mode: Mode
    let color: Color

    private var label: LocalizedStringKey {
        switch mode {
        case .transcribing: return "Transcribing"
        case .enhancing: return "Enhancing"
        }
    }

    private var animationSpeed: Double {
        switch mode {
        case .transcribing: return 0.18
        case .enhancing: return 0.22
        }
    }

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .foregroundColor(color)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            ProgressAnimation(color: color, animationSpeed: animationSpeed)
        }
        .frame(height: 28)  // matches AudioVisualizer maxHeight to prevent layout shift
    }
}
