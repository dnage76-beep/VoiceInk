import AppKit
import Foundation

struct RecordingContextSnapshot {
    var capturedAt = Date()
    var selectedText: String?
    var clipboardText: String?
    var screenText: String?
}

@MainActor
final class RecordingContextSnapshotStore {
    private(set) var snapshot = RecordingContextSnapshot()

    func updateSelectedText(_ text: String?) {
        snapshot.selectedText = Self.normalized(text)
    }

    func updateClipboardText(_ text: String?) {
        snapshot.clipboardText = Self.normalized(text)
    }

    func updateScreenText(_ text: String?) {
        snapshot.screenText = Self.normalized(text)
    }

    private static func normalized(_ text: String?) -> String? {
        guard let text else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

/// Which context sources this dictation can actually use. Capturing
/// unconditionally meant every dictation took a screenshot and ran OCR even
/// for modes with screen capture switched off; the flags let the engine skip
/// work (and a silent screenshot) the prompt builder would only filter out
/// again at read time.
struct RecordingContextNeeds {
    var clipboardText: Bool
    var selectedText: Bool
    var screenText: Bool

    static let all = RecordingContextNeeds(clipboardText: true, selectedText: true, screenText: true)
}

@MainActor
enum RecordingContextCaptureService {
    static func startCapture(
        into store: RecordingContextSnapshotStore,
        needs: RecordingContextNeeds = .all
    ) -> [Task<Void, Never>] {
        var tasks: [Task<Void, Never>] = []

        if needs.clipboardText {
            tasks.append(
                Task { @MainActor in
                    store.updateClipboardText(NSPasteboard.general.string(forType: .string))
                })
        }

        if needs.selectedText {
            tasks.append(
                Task { @MainActor in
                    guard !Task.isCancelled else { return }
                    let selectedText = await SelectedTextService.fetchSelectedText()
                    guard !Task.isCancelled else { return }
                    store.updateSelectedText(selectedText)
                })
        }

        if needs.screenText {
            tasks.append(
                Task { @MainActor in
                    guard CGPreflightScreenCaptureAccess(), !Task.isCancelled else { return }
                    let screenCaptureService = ScreenCaptureService()
                    let screenText = await screenCaptureService.captureAndExtractText()
                    guard !Task.isCancelled else { return }
                    store.updateScreenText(screenText)
                })
        }

        return tasks
    }
}
