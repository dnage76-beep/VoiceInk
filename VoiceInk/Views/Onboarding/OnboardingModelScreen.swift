import SwiftUI

struct OnboardingModelScreen: View {
    let contentMaxWidth: CGFloat
    let localModel: FluidAudioModel?
    var alternativeLocalModels: [FluidAudioModel] = []
    var onSelectLocalModel: ((FluidAudioModel) -> Void)? = nil
    var isLocalModelDownloaded: ((FluidAudioModel) -> Bool)? = nil
    let setupKind: OnboardingTranscriptionSetupKind
    let providerOptions: [any CloudProvider]
    @Binding var selectedProviderKey: String
    let isLocalDownloaded: Bool
    let isLocalDownloading: Bool
    let localDownloadStatus: FluidAudioDownloadStatus?
    let isSetupReady: Bool
    let onSelectSetupKind: (OnboardingTranscriptionSetupKind) -> Void
    let onDownload: (FluidAudioModel) -> Void
    let onVerificationChanged: () -> Void
    let onBack: () -> Void
    let onContinue: () -> Void

    var body: some View {
        OnboardingStepScreen(
            stage: .model,
            contentMaxWidth: contentMaxWidth
        ) {
            OnboardingTranscriptionSetupCard(
                localModel: localModel,
                alternativeLocalModels: alternativeLocalModels,
                setupKind: setupKind,
                providerOptions: providerOptions,
                selectedProviderKey: $selectedProviderKey,
                isLocalDownloaded: isLocalDownloaded,
                isLocalDownloading: isLocalDownloading,
                localDownloadStatus: localDownloadStatus,
                onSelectSetupKind: onSelectSetupKind,
                onDownloadLocalModel: onDownload,
                onSelectLocalModel: onSelectLocalModel,
                isLocalModelDownloaded: isLocalModelDownloaded,
                onVerificationChanged: onVerificationChanged
            )
        } bottomBar: {
            OnboardingBottomBar(
                leadingTitle: "Back",
                primaryTitle: "Continue",
                isPrimaryEnabled: isSetupReady && !(setupKind == .local && isLocalDownloading),
                onLeading: onBack,
                onPrimary: onContinue
            )
        }
    }
}
