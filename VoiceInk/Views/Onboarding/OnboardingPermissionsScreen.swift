import SwiftUI

struct OnboardingPermissionsScreen: View {
    let contentMaxWidth: CGFloat
    let isComplete: Bool
    let activePermission: OnboardingPermissionKind
    let hasRequestedScreenRecording: Bool
    let stepNumber: (OnboardingPermissionKind) -> Int
    let status: (OnboardingPermissionKind) -> OnboardingPermissionStatus
    let isLocked: (OnboardingPermissionKind) -> Bool
    let actionTitle: (OnboardingPermissionKind) -> String
    let onSelect: (OnboardingPermissionKind) -> Void
    let onAction: (OnboardingPermissionKind) -> Void
    let onQuit: () -> Void
    let onRecheck: () -> Void
    let onContinue: () -> Void

    var body: some View {
        OnboardingStepScreen(
            stage: .permissions,
            contentMaxWidth: contentMaxWidth
        ) {
            permissionList
        } bottomBar: {
            OnboardingBottomBar(
                leadingTitle: "Recheck",
                primaryTitle: "Continue",
                isPrimaryEnabled: isComplete,
                onLeading: onRecheck,
                onPrimary: onContinue
            )
        }
    }

    private var permissionList: some View {
        VStack(spacing: 10) {
            ForEach(OnboardingPermissionKind.allCases) { permission in
                PermissionStepRow(
                    kind: permission,
                    stepNumber: stepNumber(permission),
                    descriptor: permission.descriptor,
                    status: status(permission),
                    isActive: !isComplete && activePermission == permission,
                    isLocked: isLocked(permission),
                    showsRestartHint: showsRestartHint(for: permission),
                    actionTitle: actionTitle(permission),
                    onSelect: {
                        guard !isLocked(permission) else { return }
                        onSelect(permission)
                    },
                    onAction: {
                        onAction(permission)
                    },
                    onQuit: onQuit
                )
            }
        }
    }

    private func showsRestartHint(for permission: OnboardingPermissionKind) -> Bool {
        switch permission {
        case .screenRecording:
            // Prompted but not yet granted: the restart is what applies it.
            return hasRequestedScreenRecording && !status(.screenRecording).isGranted
        case .accessibility:
            // Granted but not yet picked up: without a relaunch the hotkey
            // records and then types nothing.
            return status(.accessibility).isGranted
        case .microphone:
            return false
        }
    }
}
