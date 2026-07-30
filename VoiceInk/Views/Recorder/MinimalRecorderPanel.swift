import AppKit
import SwiftUI

/// Host window for the Minimalist recorder. Same floating, all-spaces,
/// non-activating behavior as the notch panel, but sized to a fixed small pill
/// instead of derived from the physical notch, and centered on whichever screen
/// currently has the mouse so it appears where the user is working.
class MinimalRecorderPanel: KeyablePanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    /// Roomy enough for the pill plus its drop shadow and scale-in, no more.
    private static let contentSize = CGSize(width: 200, height: 60)

    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .hudWindow],
            backing: .buffered,
            defer: false
        )

        self.isFloatingPanel = true
        self.canHide = false
        self.level = .statusBar + 3
        self.backgroundColor = .clear
        self.isOpaque = false
        self.alphaValue = 1.0
        self.hasShadow = false
        self.isMovableByWindowBackground = false
        self.hidesOnDeactivate = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        self.appearance = NSAppearance(named: .darkAqua)
        self.styleMask.remove(.titled)
        self.titlebarAppearsTransparent = true
        self.titleVisibility = .hidden
        self.standardWindowButton(.closeButton)?.isHidden = true
        self.isMovable = false

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleScreenParametersChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    static func calculateWindowFrame() -> NSRect {
        let screen =
            NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) }
            ?? NSScreen.main

        guard let screen else {
            return NSRect(origin: .zero, size: contentSize)
        }

        // Anchor under the menu bar rather than the raw top edge, so the pill
        // never lands behind it on a notchless display.
        let topEdge = screen.frame.maxY - (screen.frame.maxY - screen.visibleFrame.maxY)

        return NSRect(
            x: screen.frame.midX - contentSize.width / 2,
            y: topEdge - contentSize.height,
            width: contentSize.width,
            height: contentSize.height
        )
    }

    func show() {
        setFrame(MinimalRecorderPanel.calculateWindowFrame(), display: true)
        orderFrontRegardless()
    }

    @objc private func handleScreenParametersChange() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self else { return }
            self.setFrame(MinimalRecorderPanel.calculateWindowFrame(), display: true)
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

@MainActor
class MinimalWindowManager {
    private var windowController: NSWindowController?
    private var panel: MinimalRecorderPanel?

    private let makeView: () -> AnyView

    init(
        engine: VoiceInkEngine,
        recorder: Recorder,
        onRecordButtonTapped: @escaping () -> Void
    ) {
        self.makeView = {
            AnyView(
                MinimalRecorderView(
                    stateProvider: engine,
                    recorder: recorder,
                    onRecordButtonTapped: onRecordButtonTapped
                )
            )
        }
    }

    func show() {
        if panel == nil { initializeWindow() }
        panel?.show()
    }

    func hide() {
        panel?.orderOut(nil)
    }

    func destroyWindow() {
        deinitializeWindow()
    }

    private func initializeWindow() {
        deinitializeWindow()
        let newPanel = MinimalRecorderPanel(contentRect: MinimalRecorderPanel.calculateWindowFrame())
        let hostingController = NotchRecorderHostingController(rootView: makeView())
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
