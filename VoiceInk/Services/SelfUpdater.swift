import Foundation
import os

/// Manual updates for the GitHub-distributed build. Nothing runs on a timer:
/// the ONLY network request happens when the user presses Check for Updates,
/// and installing just runs the same installer script new users get, which
/// quits the app, swaps the bundle in place, and relaunches it.
@MainActor
final class SelfUpdater: ObservableObject {
    enum State: Equatable {
        case idle
        case checking
        case upToDate
        case available(version: String)
        case installing
        case failed(String)
    }

    @Published private(set) var state: State = .idle

    static let shared = SelfUpdater()

    private static let latestReleaseURL = URL(
        string: "https://api.github.com/repos/dnage76-beep/VoiceInk/releases/latest")!
    private static let installCommand =
        "curl -fsSL https://raw.githubusercontent.com/dnage76-beep/VoiceInk/main/install.sh | bash"
    private let logger = Logger(subsystem: "com.prakashjoshipax.voiceink", category: "SelfUpdater")

    private init() {}

    var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    func checkForUpdates() {
        guard state != .checking, state != .installing else { return }
        state = .checking

        Task {
            do {
                var request = URLRequest(url: Self.latestReleaseURL)
                request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
                request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
                let (data, response) = try await URLSession.shared.data(for: request)

                guard let http = response as? HTTPURLResponse, http.statusCode == 200,
                    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                    let tag = json["tag_name"] as? String
                else {
                    state = .failed(String(localized: "Couldn't read the latest release from GitHub."))
                    return
                }

                let latest = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
                if isVersion(latest, newerThan: currentVersion) {
                    state = .available(version: latest)
                } else {
                    state = .upToDate
                }
            } catch {
                logger.error("Update check failed: \(error, privacy: .public)")
                state = .failed(String(localized: "No connection. Check your internet and try again."))
            }
        }
    }

    /// Runs the installer detached, so it survives the moment the script
    /// quits this app to replace it. The script relaunches VoiceInk itself.
    func installUpdate() {
        guard case .available = state else { return }
        state = .installing

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", Self.installCommand]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        // On success the script quits this app, so this handler only ever
        // delivers bad news: if we are still alive when the installer exits,
        // it did not finish.
        process.terminationHandler = { [logger] finished in
            Task { @MainActor in
                guard SelfUpdater.shared.state == .installing else { return }
                logger.error("Installer exited early (status \(finished.terminationStatus, privacy: .public))")
                SelfUpdater.shared.state = .failed(
                    String(localized: "The update didn't finish. Check your internet and try again."))
            }
        }

        do {
            try process.run()
        } catch {
            logger.error("Failed to launch installer: \(error, privacy: .public)")
            state = .failed(String(localized: "Couldn't start the installer."))
        }
    }

    /// Numeric dotted-component comparison: "1.2.10" beats "1.2.9".
    private func isVersion(_ candidate: String, newerThan current: String) -> Bool {
        let a = candidate.split(separator: ".").map { Int($0) ?? 0 }
        let b = current.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(a.count, b.count) {
            let x = i < a.count ? a[i] : 0
            let y = i < b.count ? b[i] : 0
            if x != y { return x > y }
        }
        return false
    }
}
