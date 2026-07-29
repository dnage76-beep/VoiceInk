import SwiftUI

/// Shown in place of the API key step when the `claude` binary is on PATH.
/// Cleanup runs through the existing Claude subscription, so there is nothing
/// to sign up for and no key to paste: this screen states what was found and
/// gets out of the way.
struct OnboardingClaudeCLIScreen: View {
    let contentMaxWidth: CGFloat
    let onBack: () -> Void
    let onContinue: () -> Void
    let onUseAnotherProvider: () -> Void

    var body: some View {
        OnboardingStepScreen(
            stage: .api,
            contentMaxWidth: contentMaxWidth
        ) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(AppTheme.Status.positive)

                    Text("Claude Code found on this Mac")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppTheme.Text.primary)
                }

                Text(
                    "Cleanup runs through the Claude subscription you already have. Only the transcript is sent, and there is no API key to set up."
                )
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.Text.secondary)
                .fixedSize(horizontal: false, vertical: true)

                Button("Use a different provider instead", action: onUseAnotherProvider)
                    .buttonStyle(.link)
                    .font(.system(size: 12))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous)
                    .fill(AppTheme.Surface.control)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous)
                    .strokeBorder(AppTheme.Border.card, lineWidth: 1)
            )
        } bottomBar: {
            OnboardingBottomBar(
                leadingTitle: "Back",
                primaryTitle: "Continue",
                isPrimaryEnabled: true,
                onLeading: onBack,
                onPrimary: onContinue,
                skipTitle: nil,
                onSkip: nil
            )
        }
    }
}
