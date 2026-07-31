import Foundation
import SwiftData

@Model
final class SessionMetric {
    var id: UUID = UUID()
    var transcriptionId: UUID = UUID()
    var timestamp: Date = Date()
    var source: String?
    var wordCount: Int = 0
    var audioDuration: TimeInterval = 0
    var transcriptionModelName: String?
    var transcriptionDuration: TimeInterval?
    var speedFactor: Double?
    @Attribute(originalName: "powerModeName")
    var modeName: String?
    var aiEnhancementModelName: String?
    var enhancementDuration: TimeInterval?
    var enhancementEstimatedTokenCount: Int?
    /// Bundle identifier of whatever app was frontmost when the recording
    /// started, e.g. "com.apple.mail". Optional because every session recorded
    /// before this shipped has no value, and because the frontmost app is not
    /// always knowable. Never leaves the Mac.
    var targetAppBundleID: String?
    /// Human-readable name for the same app, stored alongside the bundle ID so
    /// the dashboard can label a row for an app that has since been uninstalled.
    var targetAppName: String?

    init(
        transcriptionId: UUID,
        timestamp: Date = Date(),
        source: String? = "recorder",
        wordCount: Int,
        audioDuration: TimeInterval,
        transcriptionModelName: String?,
        transcriptionDuration: TimeInterval?,
        speedFactor: Double?,
        modeName: String?,
        aiEnhancementModelName: String?,
        enhancementDuration: TimeInterval?,
        enhancementEstimatedTokenCount: Int? = nil,
        targetAppBundleID: String? = nil,
        targetAppName: String? = nil
    ) {
        self.id = UUID()
        self.transcriptionId = transcriptionId
        self.timestamp = timestamp
        self.source = source
        self.wordCount = wordCount
        self.audioDuration = audioDuration
        self.transcriptionModelName = transcriptionModelName
        self.transcriptionDuration = transcriptionDuration
        self.speedFactor = speedFactor
        self.modeName = modeName
        self.aiEnhancementModelName = aiEnhancementModelName
        self.enhancementDuration = enhancementDuration
        self.enhancementEstimatedTokenCount = enhancementEstimatedTokenCount
        self.targetAppBundleID = targetAppBundleID
        self.targetAppName = targetAppName
    }
}
