import Testing

@testable import VoiceInk

/// Freeing a loaded model while a dictation is using it loses the user's
/// audio, so the rules about when a release may happen are worth pinning down.
@MainActor
struct ModelResidencyControllerTests {
    /// Counts releases so a test can tell "not yet" from "never".
    private final class ReleaseCounter {
        var count = 0
    }

    private func makeController(
        idleTimeout: Double = 3600
    ) -> (ModelResidencyController, ReleaseCounter) {
        let counter = ReleaseCounter()
        let controller = ModelResidencyController(idleTimeout: idleTimeout) {
            counter.count += 1
        }
        return (controller, counter)
    }

    @Test func releaseIsDeferredWhileWorkIsInFlight() async throws {
        let (controller, counter) = makeController()

        controller.noteActivityStarted()
        await controller.releaseNow(reason: "sleep")
        #expect(counter.count == 0)

        controller.noteActivityFinished()
        try await Task.sleep(for: .milliseconds(150))
        #expect(counter.count == 1)
    }

    @Test func modelsAreHeldUntilEveryUserFinishes() async throws {
        let (controller, counter) = makeController()

        // A prewarm and a dictation can overlap.
        controller.noteActivityStarted()
        controller.noteActivityStarted()
        await controller.releaseNow(reason: "model changed")

        controller.noteActivityFinished()
        try await Task.sleep(for: .milliseconds(100))
        #expect(counter.count == 0)

        controller.noteActivityFinished()
        try await Task.sleep(for: .milliseconds(150))
        #expect(counter.count == 1)
    }

    @Test func idleTimeoutReleasesModels() async throws {
        let (controller, counter) = makeController(idleTimeout: 0.2)

        controller.noteActivityStarted()
        controller.noteActivityFinished()

        try await Task.sleep(for: .milliseconds(500))
        #expect(counter.count == 1)
    }

    @Test func newDictationCancelsAPendingIdleRelease() async throws {
        let (controller, counter) = makeController(idleTimeout: 0.3)

        controller.noteActivityStarted()
        controller.noteActivityFinished()
        try await Task.sleep(for: .milliseconds(100))

        controller.noteActivityStarted()
        try await Task.sleep(for: .milliseconds(400))

        #expect(counter.count == 0)
        #expect(controller.isResident)
    }

    @Test func releasingWithNothingLoadedDoesNothing() async {
        let (controller, counter) = makeController()

        await controller.releaseNow(reason: "sleep")

        #expect(counter.count == 0)
    }

    @Test func modelsAreNotFreedTwice() async throws {
        let (controller, counter) = makeController()

        controller.noteActivityStarted()
        controller.noteActivityFinished()

        await controller.releaseNow(reason: "sleep")
        await controller.releaseNow(reason: "model changed")

        #expect(counter.count == 1)
    }
}
