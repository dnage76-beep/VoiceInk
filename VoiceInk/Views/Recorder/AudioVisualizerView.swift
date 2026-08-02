import SwiftUI

// Center-origin Siri-style ripple. Crests are born in the middle of the pill
// and travel outward symmetrically (|u| folds the x axis around the center),
// so speech reads as energy blooming from the center instead of a wave
// scrolling left to right. Lineage: replaced a port of SwiftSiriWaveformView
// (MIT, (c) 2015 Alankar Misra / SCSiriWaveformView (c) Stefan Ceriu).
struct AudioVisualizer: View {
    let audioMeter: AudioMeter
    let color: Color
    let isActive: Bool

    private let waveWidth: CGFloat = 76
    private let waveHeight: CGFloat = 28

    @State private var engine = SiriWaveEngine()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { context in
            let frame = engine.frame(
                meter: audioMeter,
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
        .frame(width: waveWidth, height: waveHeight)
    }
}

// Shared center-origin ripple drawing, so every recorder style speaks the
// same motion vocabulary.
enum SiriRippleRenderer {
    // Layers ripple outward at their own frequency and pace; the offsets keep
    // the interference shimmering instead of pulsing in lockstep. Every speed
    // is a multiple of 0.1 so SiriWaveEngine's 20π time wrap stays seamless.
    struct WaveLayer {
        let frequency: CGFloat
        let speed: Double
        let amplitude: CGFloat
        let lineWidth: CGFloat
        let opacity: Double
    }

    static let standardLayers: [WaveLayer] = [
        WaveLayer(frequency: 1.2, speed: 5.2, amplitude: 1.00, lineWidth: 1.8, opacity: 1.00),
        WaveLayer(frequency: 1.7, speed: 6.6, amplitude: 0.70, lineWidth: 1.0, opacity: 0.50),
        WaveLayer(frequency: 2.3, speed: 7.9, amplitude: 0.45, lineWidth: 0.8, opacity: 0.32),
        WaveLayer(frequency: 0.8, speed: 3.9, amplitude: 0.60, lineWidth: 1.0, opacity: 0.42),
    ]

    static func draw(
        in canvasContext: GraphicsContext,
        size: CGSize,
        amplitude: Double,
        time: Double,
        color: Color,
        layers: [WaveLayer] = standardLayers
    ) {
        let midX = size.width / 2
        let midY = size.height / 2
        let maxAmplitude = size.height / 2 - 2

        for layer in layers {
            var path = Path()
            var x: CGFloat = 0
            var isFirstPoint = true
            while x <= size.width {
                let u = (x - midX) / midX  // -1 at left edge, 0 center, 1 right
                // Envelope pins both edges and peaks at the center.
                let envelope = pow(max(1 - u * u, 0), 1.4)
                let ripple = sin(2 * .pi * layer.frequency * abs(u) - layer.speed * time)
                let y = midY + envelope * maxAmplitude * layer.amplitude * CGFloat(amplitude) * ripple
                if isFirstPoint {
                    path.move(to: CGPoint(x: x, y: y))
                    isFirstPoint = false
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
                x += 1
            }

            // Horizontal fade keeps the brightness centered, matching where
            // the motion originates.
            canvasContext.stroke(
                path,
                with: .linearGradient(
                    Gradient(stops: [
                        .init(color: color.opacity(0), location: 0),
                        .init(color: color.opacity(layer.opacity), location: 0.35),
                        .init(color: color.opacity(layer.opacity), location: 0.65),
                        .init(color: color.opacity(0), location: 1),
                    ]),
                    startPoint: CGPoint(x: 0, y: midY),
                    endPoint: CGPoint(x: size.width, y: midY)
                ),
                style: StrokeStyle(lineWidth: layer.lineWidth, lineCap: .round, lineJoin: .round)
            )
        }
    }
}

// Smooths the meter into an amplitude with a fast attack and a slow release:
// speech snaps the wave up instantly, silence lets it settle instead of
// flickering frame to frame.
final class SiriWaveEngine {
    struct WaveFrame {
        var amplitude: Double
        var time: Double
    }

    private var lastTime: TimeInterval?
    private var amplitude: Double = 0

    func frame(meter: AudioMeter, time: TimeInterval, isActive: Bool) -> WaveFrame {
        let dt = min(max(time - (lastTime ?? time), 0), 0.05)
        lastTime = time

        // Wrapping keeps sin() arguments small. The 20π period is seamless:
        // every speed used is a multiple of 0.1, so speed × 20π is always a
        // whole number of 2π cycles and the wrap lands mid-phase nowhere.
        let wrappedTime = time.truncatingRemainder(dividingBy: 20 * .pi)

        // A slow breath at idle keeps the wave alive without shouting.
        let idle = 0.10 + 0.05 * sin(wrappedTime * 1.3)
        let target = isActive ? max(meter.averagePower, idle) : idle

        let timeConstant = target > amplitude ? 0.05 : 0.22
        amplitude += (target - amplitude) * (dt > 0 ? 1 - exp(-dt / timeConstant) : 1)

        return WaveFrame(amplitude: amplitude, time: wrappedTime)
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
