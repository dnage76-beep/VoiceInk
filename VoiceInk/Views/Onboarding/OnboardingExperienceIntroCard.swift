import SwiftUI

struct OnboardingExperienceIntroCard: View {
    let step: OnboardingExperienceStep
    let shortcutAction: ShortcutAction
    let hasShortcut: Bool
    let onShortcutChanged: () -> Void

    @State private var isVisible = false

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(LocalizedStringKey(introText))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(AppTheme.Text.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if showsShortcutControl {
                OnboardingShortcutSetupView(
                    action: shortcutAction,
                    onShortcutChanged: onShortcutChanged
                )
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .fixedSize(horizontal: false, vertical: false)
        .opacity(isVisible ? 1 : 0)
        .scaleEffect(isVisible ? 1 : 0.98)
        .offset(y: isVisible ? 0 : 10)
        .onAppear {
            isVisible = false
            withAnimation(.easeInOut(duration: 0.3).delay(0.08)) {
                isVisible = true
            }
        }
    }

    private var introText: String {
        if let shortcutIntroTitle = step.shortcutIntroTitle {
            return shortcutIntroTitle
        }

        return hasShortcut ? "Keyboard shortcut:" : "Choose a shortcut to get started."
    }

    private var showsShortcutControl: Bool {
        step.showsShortcutControl
    }
}

/// Shown once, on the first dictation step: pick where the recorder appears
/// before it appears for the first time. Same previews as Settings, and the
/// choice takes effect immediately because it goes through the live manager.
struct OnboardingRecorderStyleCard: View {
    @EnvironmentObject private var recorderUIManager: RecorderUIManager

    @State private var isVisible = false

    var body: some View {
        VStack(spacing: 10) {
            Text("Where should the recorder appear?")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppTheme.Text.primary)

            RecorderStylePicker(selection: $recorderUIManager.recorderPanelStyle)

            Text(recorderUIManager.recorderPanelStyle.previewDescription)
                .font(.system(size: 11))
                .foregroundColor(AppTheme.Text.secondary)
                .multilineTextAlignment(.center)
                .frame(minHeight: 26, alignment: .top)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(AppCardBackground(cornerRadius: 12))
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : 10)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.3).delay(0.16)) {
                isVisible = true
            }
        }
    }
}
