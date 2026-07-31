import Foundation
import Testing

@testable import VoiceInk

/// A failed model download used to be invisible: the catch only logged, and
/// `defer` immediately cleared the progress status, so the onboarding screen
/// fell back to "not downloaded" with no reason and no prompt to retry. These
/// pin the messages a user actually sees.
@MainActor
struct ModelDownloadFailureTests {

    private func urlError(_ code: URLError.Code) -> Error {
        URLError(code)
    }

    @Test func noConnectionSaysSo() {
        let message = FluidAudioModelManager.userFacingMessage(
            for: urlError(.notConnectedToInternet)
        )
        #expect(message.contains("No internet connection"))
    }

    @Test func droppedConnectionIsTreatedAsOffline() {
        let message = FluidAudioModelManager.userFacingMessage(
            for: urlError(.networkConnectionLost)
        )
        #expect(message.contains("No internet connection"))
    }

    @Test func timeoutSaysTimedOut() {
        let message = FluidAudioModelManager.userFacingMessage(for: urlError(.timedOut))
        #expect(message.contains("timed out"))
    }

    @Test func cancellationIsNotReportedAsAFailure() {
        let message = FluidAudioModelManager.userFacingMessage(for: urlError(.cancelled))
        #expect(message.contains("cancelled"))
    }

    /// A big model on a full disk is a real setup failure, and "try again"
    /// would be useless advice, so it gets its own message.
    @Test func outOfDiskSpaceIsCalledOut() {
        let error = NSError(
            domain: NSCocoaErrorDomain,
            code: NSFileWriteOutOfSpaceError
        )
        let message = FluidAudioModelManager.userFacingMessage(for: error)
        #expect(message.contains("disk space"))
    }

    /// Other network errors still get an actionable sentence rather than a raw
    /// URLSession description.
    @Test func otherNetworkErrorsGetGenericAdvice() {
        let message = FluidAudioModelManager.userFacingMessage(
            for: urlError(.badServerResponse)
        )
        #expect(message.contains("Check your connection"))
    }

    @Test func unknownErrorsStillSurfaceSomething() {
        struct Weird: LocalizedError {
            var errorDescription: String? { "the model was rejected" }
        }
        let message = FluidAudioModelManager.userFacingMessage(for: Weird())
        #expect(message.contains("the model was rejected"))
        #expect(!message.isEmpty)
    }
}

/// The status type carries the failure so the card can branch on it.
struct FluidAudioDownloadStatusTests {

    @Test func progressStatusIsNotAFailure() {
        let status = FluidAudioDownloadStatus(fractionCompleted: 0.4, message: "Downloading")
        #expect(status.hasFailed == false)
        #expect(status.failure == nil)
    }

    @Test func failureStatusReportsItself() {
        let status = FluidAudioDownloadStatus(
            fractionCompleted: 0,
            message: "No internet connection.",
            failure: "No internet connection."
        )
        #expect(status.hasFailed)
    }
}
