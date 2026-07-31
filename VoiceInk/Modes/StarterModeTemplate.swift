import Foundation

enum StarterModeKind: String, CaseIterable, Identifiable {
    case clean
    case enhance
    case email
    case coding
    case texting

    var id: String { rawValue }
}

struct StarterModeTemplate: Identifiable {
    let kind: StarterModeKind
    let id: UUID
    let name: String
    let icon: ModeIcon
    let description: String
    let guidance: String
    let promptId: UUID?
    let outputMode: ModeOutputMode
    let usesAIEnhancement: Bool
    let useSelectedTextContext: Bool
    let useScreenCapture: Bool
    let isDefault: Bool

    var featureLabels: [String] {
        var labels = ["Transcription", "Realtime"]

        if usesAIEnhancement {
            labels.append("AI")
        } else {
            labels.append("No AI")
        }

        if outputMode == .respond {
            labels.append("Respond")
        } else {
            labels.append("Paste")
        }

        return labels
    }
}

enum StarterModeCatalog {
    static let templates: [StarterModeTemplate] = [
        StarterModeTemplate(
            kind: .clean,
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000001")!,
            name: "Dictation",
            icon: .symbol("mic.fill"),
            description: String(localized: "Fast transcription with no AI enhancement."),
            guidance: String(
                localized:
                    "Use this when you want the quickest possible voice-to-text result. It records with your configured transcription model and pastes the transcript as-is."
            ),
            promptId: nil,
            outputMode: .paste,
            usesAIEnhancement: false,
            useSelectedTextContext: false,
            useScreenCapture: false,
            isDefault: true
        ),
        StarterModeTemplate(
            kind: .enhance,
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000002")!,
            name: "Enhancement",
            icon: .symbol("sparkles"),
            description: "Clean up dictated text while preserving your meaning.",
            guidance:
                "Use this for everyday writing when you want grammar, flow, and light formatting improved before the result is pasted.",
            promptId: PromptTemplates.defaultPromptId,
            outputMode: .paste,
            usesAIEnhancement: true,
            useSelectedTextContext: true,
            useScreenCapture: true,
            isDefault: false
        ),
        StarterModeTemplate(
            kind: .email,
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000003")!,
            name: "Email",
            icon: .symbol("envelope.fill"),
            description: "Turn a rough thought into a clean email.",
            guidance:
                "Use this after selecting relevant text or opening the related window. VoiceInk uses that context to shape a clear email draft.",
            promptId: PromptTemplates.emailPromptId,
            outputMode: .paste,
            usesAIEnhancement: true,
            useSelectedTextContext: true,
            useScreenCapture: true,
            isDefault: false
        ),
        StarterModeTemplate(
            kind: .coding,
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000006")!,
            name: "Agentic Coding",
            icon: .symbol("terminal.fill"),
            description: "Dictate to AI coding agents without losing technical terms.",
            guidance:
                "Use this when talking to Claude Code, Cursor, or a terminal. Commands, file paths, and identifiers are preserved exactly; spoken symbols become real symbols.",
            promptId: PromptTemplates.codingPromptId,
            outputMode: .paste,
            usesAIEnhancement: true,
            useSelectedTextContext: false,
            useScreenCapture: false,
            isDefault: false
        ),
        StarterModeTemplate(
            kind: .texting,
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000007")!,
            name: "Texting",
            icon: .symbol("message.fill"),
            description: "Casual messages that sound like you.",
            guidance:
                "Use this in Messages and chat apps. Your tone and slang stay; fillers go. Nothing gets formalized.",
            promptId: PromptTemplates.textingPromptId,
            outputMode: .paste,
            usesAIEnhancement: true,
            useSelectedTextContext: false,
            useScreenCapture: false,
            isDefault: false
        ),
    ]

    static var ids: Set<UUID> {
        Set(templates.map(\.id))
    }
}
