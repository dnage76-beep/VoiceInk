import Foundation
import SwiftUI

/// Groups the apps you dictate into by what you were probably doing there.
///
/// The categories mirror the way people describe their own day ("I answer email
/// and I write docs") rather than the way the OS organises apps. Anything we do
/// not recognise falls into `.other`, which is honest: a long tail of unknown
/// apps is a real answer, not a failure.
enum DictationCategory: String, Codable, CaseIterable, Sendable, Identifiable {
    case aiPrompts
    case email
    case workMessages
    case personalMessages
    case documents
    case code
    case browsing
    case other

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .aiPrompts: return "AI prompts"
        case .email: return "Emails"
        case .workMessages: return "Work messages"
        case .personalMessages: return "Personal messages"
        case .documents: return "Documents"
        case .code: return "Code"
        case .browsing: return "Browsing"
        case .other: return "Other apps"
        }
    }

    /// Plain-string form of `title`, for accessibility labels and anywhere else
    /// a LocalizedStringKey cannot be interpolated.
    var localizedTitle: String {
        switch self {
        case .aiPrompts: return String(localized: "AI prompts")
        case .email: return String(localized: "Emails")
        case .workMessages: return String(localized: "Work messages")
        case .personalMessages: return String(localized: "Personal messages")
        case .documents: return String(localized: "Documents")
        case .code: return String(localized: "Code")
        case .browsing: return String(localized: "Browsing")
        case .other: return String(localized: "Other apps")
        }
    }

    var symbolName: String {
        switch self {
        case .aiPrompts: return "sparkles"
        case .email: return "envelope"
        case .workMessages: return "bubble.left.and.bubble.right"
        case .personalMessages: return "message"
        case .documents: return "doc.text"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .browsing: return "safari"
        case .other: return "square.grid.2x2"
        }
    }

    /// Display order: the categories a person is most likely to care about
    /// first, with the catch-all last regardless of size.
    var sortIndex: Int {
        switch self {
        case .aiPrompts: return 0
        case .email: return 1
        case .workMessages: return 2
        case .personalMessages: return 3
        case .documents: return 4
        case .code: return 5
        case .browsing: return 6
        case .other: return 7
        }
    }

    /// Maps a bundle identifier to a category. Matching is by prefix and by
    /// keyword so that variants ("com.google.Chrome.beta", "com.tinyspeck.slackmacgap")
    /// land in the right bucket without an exhaustive list.
    static func category(forBundleID bundleID: String?) -> DictationCategory {
        guard let bundleID = bundleID?.lowercased(), !bundleID.isEmpty else {
            return .other
        }

        for (category, needles) in bundleKeywords {
            if needles.contains(where: { bundleID.contains($0) }) {
                return category
            }
        }

        return .other
    }

    /// Ordered because a single bundle ID can match more than one rule and the
    /// first hit should win: Slack contains "slack" (work messages) but a
    /// browser check on "com.slack" must not steal it.
    private static let bundleKeywords: [(DictationCategory, [String])] = [
        (
            .aiPrompts,
            ["openai", "chatgpt", "anthropic", "claude", "perplexity", "poe.", "gemini", "copilot"]
        ),
        (
            .email,
            ["com.apple.mail", "mailmate", "sparkmailapp", "readdle.smartemail", "superhuman", "missiveapp", "thunderbird", "outlook"]
        ),
        (
            .workMessages,
            ["slack", "discord", "zoom.us", "microsoft.teams", "webex", "mattermost"]
        ),
        (
            .personalMessages,
            ["com.apple.ichat", "com.apple.messages", "whatsapp", "telegram", "signal", "facebook.messenger"]
        ),
        (
            .documents,
            [
                "com.apple.textedit", "com.apple.iwork", "com.apple.notes", "notion",
                "obsidian", "bear", "ulysses", "scrivener", "craft", "microsoft.word",
                "google.docs", "evernote", "roamresearch", "logseq",
            ]
        ),
        (
            .code,
            [
                "com.apple.dt.xcode", "visualstudio", "vscode", "jetbrains", "sublimetext",
                "iterm", "com.apple.terminal", "warp", "nova", "zed", "cursor", "githubdesktop",
                "com.googlecode.iterm2",
            ]
        ),
        (
            .browsing,
            ["com.apple.safari", "google.chrome", "mozilla.firefox", "microsoft.edgemac", "company.thebrowser", "brave.browser", "operasoftware"]
        ),
    ]
}

/// One app's share of your dictation, used for the per-app rows.
struct AppDictationUsage: Codable, Equatable, Identifiable, Sendable {
    var id: String { bundleID ?? name }
    let bundleID: String?
    let name: String
    let category: DictationCategory
    let sessionCount: Int
    let wordCount: Int
}

/// One category's share, used for the summary bars.
struct CategoryDictationUsage: Codable, Equatable, Identifiable, Sendable {
    var id: DictationCategory { category }
    let category: DictationCategory
    let sessionCount: Int
    let wordCount: Int
}

struct DashboardAppUsageSummary: Codable, Equatable, Sendable {
    static let empty = DashboardAppUsageSummary()

    var apps: [AppDictationUsage] = []
    var categories: [CategoryDictationUsage] = []
    /// Sessions recorded before app capture shipped, which have no app attached.
    /// Surfaced so the card can explain a partial picture instead of implying
    /// the missing sessions never happened.
    var unattributedSessionCount: Int = 0

    var attributedSessionCount: Int {
        apps.reduce(0) { $0 + $1.sessionCount }
    }

    var hasData: Bool { !apps.isEmpty }

    var distinctAppCount: Int { apps.count }

    /// Share of a category's words against everything attributed, 0 to 1.
    func share(of category: DictationCategory) -> Double {
        let total = categories.reduce(0) { $0 + $1.wordCount }
        guard total > 0 else { return 0 }
        let categoryWords = categories.first { $0.category == category }?.wordCount ?? 0
        return Double(categoryWords) / Double(total)
    }
}
