import AppKit
import SwiftUI

@MainActor
class MiniWindowManager {
    private var windowController: NSWindowController?
    private var panel: MiniRecorderPanel?

    private let makeView: () -> AnyView

    init(
        engine: VoiceInkEngine,
        recorder: Recorder,
        assistantSession: AssistantSession,
        onRecordButtonTapped: @escaping () -> Void,
        onCloseTapped: @escaping () -> Void,
        onAssistantFollowUp: @escaping (String) -> Void
    ) {
        self.makeView = {
            AnyView(
                MiniRecorderView(
                    stateProvider: engine,
                    recorder: recorder,
                    assistantSession: assistantSession,
                    onRecordButtonTapped: onRecordButtonTapped,
                    onCloseTapped: onCloseTapped,
                    onAssistantFollowUp: onAssistantFollowUp
                )
            )
        }
    }

    func show() {
        if panel == nil { initializeWindow() }
        panel?.show()
    }

    /// Builds the panel and its SwiftUI hierarchy without ordering it front.
    /// Creating the hosting view is the expensive part of the first open
    /// (~200ms of main-thread work); doing it at launch makes the first Fn
    /// press as fast as every later one. show() still repositions the panel.
    func prewarm() {
        if panel == nil { initializeWindow() }
    }

    func hide() {
        panel?.orderOut(nil)
    }

    func destroyWindow() {
        deinitializeWindow()
    }

    private func initializeWindow() {
        deinitializeWindow()
        let metrics = MiniRecorderPanel.calculateWindowMetrics()
        let newPanel = MiniRecorderPanel(contentRect: metrics)
        let view = makeView()
        let hostingController = NSHostingController(rootView: view)
        newPanel.contentView = hostingController.view
        panel = newPanel
        windowController = NSWindowController(window: newPanel)
    }

    private func deinitializeWindow() {
        panel?.orderOut(nil)
        windowController?.close()
        windowController = nil
        panel = nil
    }
}
