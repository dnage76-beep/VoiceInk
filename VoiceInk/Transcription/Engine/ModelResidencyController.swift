import Foundation
import os

/// Decides when loaded transcription models are released.
///
/// Loading a local model is expensive: whisper.cpp rebuilds its context and
/// FluidAudio recompiles its ANE graphs. Releasing them after every dictation
/// means every dictation pays that cost. Instead the models stay resident and
/// are released on a deliberate signal: a long idle stretch, memory pressure,
/// or an explicit teardown (model switch, sleep, quit).
///
/// A release never interrupts work in progress. While any activity is checked
/// out, a release request is recorded and carried out when the last one
/// finishes: freeing an ANE manager mid-transcribe loses the user's dictation.
@MainActor
final class ModelResidencyController {
    /// How long models stay resident after the last dictation finishes.
    nonisolated static let defaultIdleTimeout: TimeInterval = 10 * 60

    private let idleTimeout: TimeInterval
    private let release: () async -> Void
    private let logger = Logger(
        subsystem: "com.prakashjoshipax.voiceink", category: "ModelResidency")

    private var idleTask: Task<Void, Never>?
    private var memoryPressureSource: DispatchSourceMemoryPressure?

    /// Number of dictations or prewarms currently using the loaded models.
    /// A release waits for this to reach zero.
    private var activeCount = 0
    /// Set when a release was requested while activity was in flight.
    private var pendingReleaseReason: String?
    /// Bumped whenever activity starts or a release runs, so an idle task that
    /// has already passed its cancellation check can tell it is stale.
    private var generation = 0

    /// True while models are assumed resident, so a release that would be a
    /// no-op is skipped instead of churning the logs.
    private(set) var isResident = false

    var isActive: Bool { activeCount > 0 }

    init(idleTimeout: TimeInterval = ModelResidencyController.defaultIdleTimeout, release: @escaping () async -> Void) {
        self.idleTimeout = idleTimeout
        self.release = release
        startMonitoringMemoryPressure()
    }

    deinit {
        memoryPressureSource?.cancel()
    }

    /// Call when a dictation or prewarm begins. Cancels any pending idle
    /// release so a model is never freed out from under active work.
    func noteActivityStarted() {
        activeCount += 1
        generation &+= 1
        idleTask?.cancel()
        idleTask = nil
        isResident = true
    }

    /// Call when a dictation or prewarm finishes (successfully, canceled, or
    /// failed). Starts the idle countdown, or performs a release that was
    /// requested while the work was running.
    func noteActivityFinished() {
        activeCount = max(0, activeCount - 1)
        guard activeCount == 0 else { return }

        if let reason = pendingReleaseReason {
            pendingReleaseReason = nil
            logger.notice("Running deferred release (\(reason, privacy: .public))")
            Task { await self.releaseNow(reason: reason) }
            return
        }

        guard isResident else { return }
        idleTask?.cancel()
        let startGeneration = generation
        idleTask = Task { [weak self, idleTimeout] in
            try? await Task.sleep(for: .seconds(idleTimeout))
            guard !Task.isCancelled, let self else { return }
            // Activity may have started during the sleep, in which case this
            // countdown is stale and must not free anything.
            guard self.generation == startGeneration else { return }
            self.logger.notice("Idle timeout reached, releasing models")
            await self.releaseNow(reason: "idle")
        }
    }

    /// Release immediately, e.g. on model switch, sleep, or app teardown.
    /// Deferred until in-flight work finishes.
    func releaseNow(reason: String) async {
        guard activeCount == 0 else {
            pendingReleaseReason = reason
            logger.notice("Release deferred, work in flight (\(reason, privacy: .public))")
            return
        }

        idleTask?.cancel()
        idleTask = nil
        guard isResident else { return }
        isResident = false
        generation &+= 1
        logger.notice("Releasing models (\(reason, privacy: .public))")
        await release()
    }

    private func startMonitoringMemoryPressure() {
        // Critical only: a warning is routine on a memory-constrained Mac, and
        // throwing away warm models every time one fires would undo the point
        // of keeping them.
        let source = DispatchSource.makeMemoryPressureSource(
            eventMask: [.critical], queue: .main)
        source.setEventHandler { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                await self.releaseNow(reason: "memory pressure")
            }
        }
        source.resume()
        memoryPressureSource = source
    }
}
