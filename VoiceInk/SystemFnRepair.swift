import AppKit
import Carbon.HIToolbox

/// macOS ships with "Press fn key to: Show Emoji & Symbols" (or input-source
/// switching), which fights a Fn recording shortcut: the system opens the
/// emoji palette on every tap before VoiceInk can use it. Repairs the setting
/// whenever the Fn shortcut is active, and tells the user once afterward,
/// because apps that were already running keep the old behavior cached until
/// they relaunch or the user logs back in.
@MainActor
enum SystemFnRepair {
    private static let noticePendingKey = "FnUsageRepairNoticePending"
    private static let domain = "com.apple.HIToolbox" as CFString
    private static let usageKey = "AppleFnUsageType" as CFString

    static func repairIfNeeded() {
        guard let shortcut = ShortcutStore.shortcut(for: .primaryRecording),
            shortcut.isModifierOnly,
            shortcut.keyCode == UInt16(kVK_Function)
        else { return }

        let current =
            CFPreferencesCopyValue(
                usageKey, domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost
            ) as? Int

        // A missing key is the system default, which shows the emoji palette.
        if current != 0 {
            CFPreferencesSetValue(
                usageKey, 0 as CFNumber, domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost
            )
            CFPreferencesSynchronize(domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
            UserDefaults.standard.set(true, forKey: noticePendingKey)
        }

        showPendingNoticeIfReady()
    }

    /// Deferred until onboarding is done so the alert never interrupts setup;
    /// if the repair happened during onboarding, this fires on the next check.
    private static func showPendingNoticeIfReady() {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: noticePendingKey),
            defaults.bool(forKey: "hasCompletedOnboardingV2")
        else { return }
        defaults.set(false, forKey: noticePendingKey)

        let alert = NSAlert()
        alert.messageText = "Fn key freed up for dictation"
        alert.informativeText = """
            macOS was set to open the emoji picker when you press the Fn key, which \
            blocked VoiceInk's Fn shortcut. VoiceInk turned that off for you \
            (System Settings > Keyboard > "Press fn key to" is now "Do Nothing").

            Apps that were already open may keep showing the emoji picker until you \
            quit and reopen them. If Fn still shows emoji everywhere, log out and \
            back in once.
            """
        alert.addButton(withTitle: "OK")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}
