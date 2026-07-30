import SwiftUI

/// The Minimalist recorder: a small pill that drops from the top edge of the
/// screen and is nothing but a voice animation.
///
/// No buttons. Mode switching already happens automatically from the active
/// app and trigger words, and recording is driven by the hotkey, so chrome
/// would only repeat what the system already does. The whole pill is a single
/// tap target that stops the recording, and the animation filling it is the
/// status display: moving means hearing you, spinner means working.
struct MinimalRecorderView<S: RecorderStateProvider & ObservableObject>: View {
    @ObservedObject var stateProvider: S
    @ObservedObject var recorder: Recorder
    let onRecordButtonTapped: () -> Void

    @AppStorage(MinimalVoiceAnimation.storageKey)
    private var animationRawValue = MinimalVoiceAnimation.wave.rawValue

    // MARK: - Display State

    private enum DisplayState: Equatable {
        case collapsed
        case active
    }

    private var displayState: DisplayState {
        switch stateProvider.recordingState {
        case .recording, .transcribing, .enhancing, .starting:
            return .active
        case .idle, .busy:
            return .collapsed
        }
    }

    private var animation: MinimalVoiceAnimation {
        MinimalVoiceAnimation(rawValue: animationRawValue) ?? .wave
    }

    // MARK: - Layout

    private let pillWidth: CGFloat = 124
    private let pillHeight: CGFloat = 30
    private let horizontalPadding: CGFloat = 10

    /// Sits just below the menu bar rather than flush against the top edge, so
    /// it reads as a floating pill instead of a torn-off notch.
    private let topInset: CGFloat = 3

    // MARK: - Animation

    // Same spring family as Notch, which is the motion Derek likes.
    private let expandAnimation = Animation.spring(response: 0.40, dampingFraction: 0.78)
    private let collapseAnimation = Animation.spring(response: 0.42, dampingFraction: 1.0)

    private var pillAnimation: Animation {
        displayState == .collapsed ? collapseAnimation : expandAnimation
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            pill
                .padding(.top, topInset)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(pillAnimation, value: displayState)
    }

    private var pill: some View {
        statusContent
            .padding(.horizontal, horizontalPadding)
            .frame(width: pillWidth, height: pillHeight)
            .background(Color.black)
            .clipShape(Capsule(style: .continuous))
            .contentShape(Capsule(style: .continuous))
            .onTapGesture(perform: onRecordButtonTapped)
            .help(tapHelp)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(tapHelp))
            .accessibilityAddTraits(.isButton)
            .opacity(displayState == .collapsed ? 0 : 1)
            .scaleEffect(displayState == .collapsed ? 0.86 : 1, anchor: .top)
    }

    @ViewBuilder
    private var statusContent: some View {
        switch stateProvider.recordingState {
        case .recording:
            voiceAnimation(isActive: true)
                .transition(.opacity)
        case .transcribing, .enhancing:
            // No audio left to visualize; a quiet spinner says "working".
            ProcessingIndicator(color: .white.opacity(0.86))
                .frame(maxWidth: .infinity)
                .transition(.opacity)
        case .idle, .starting, .busy:
            voiceAnimation(isActive: false)
                .transition(.opacity)
        }
    }

    @ViewBuilder
    private func voiceAnimation(isActive: Bool) -> some View {
        switch animation {
        case .wave:
            MinimalFlowingWave(
                audioMeter: recorder.audioMeter,
                color: .white,
                isActive: isActive
            )
            .frame(height: 24)
        case .scroll:
            MinimalScrollWave(
                audioMeter: recorder.audioMeter,
                color: .white,
                isActive: isActive
            )
            .frame(height: 20)
        case .bars:
            MinimalEqualizerBars(
                audioMeter: recorder.audioMeter,
                color: .white,
                isActive: isActive
            )
            .frame(height: 20)
        }
    }

    private var tapHelp: String {
        switch stateProvider.recordingState {
        case .recording:
            return String(localized: "Stop recording")
        case .transcribing:
            return String(localized: "Transcribing")
        case .enhancing:
            return String(localized: "Enhancing")
        case .idle, .starting, .busy:
            return String(localized: "Recorder")
        }
    }
}
