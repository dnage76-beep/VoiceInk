import Foundation
import SwiftData

class WordReplacementService {
    static let shared = WordReplacementService()

    private init() {}

    func applyReplacements(to text: String, using context: ModelContext) -> String {
        let descriptor = FetchDescriptor<WordReplacement>(
            predicate: #Predicate { $0.isEnabled }
        )

        guard let replacements = try? context.fetch(descriptor), !replacements.isEmpty else {
            return text  // No replacements to apply
        }

        var modifiedText = text

        // Longest phrase first ACROSS entries. Sorting whole entries by their
        // raw comma-joined length let a long comma group's short variant
        // ("new york" inside "ny, new york, nyc...") fire before another
        // entry's more specific "new york city", mangling it. Flattening the
        // groups makes specificity the only thing that decides order.
        let rules = replacements.flatMap { replacement in
            replacement.originalText
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .map { (original: $0, replacementText: replacement.replacementText) }
        }
        .sorted { $0.original.count > $1.original.count }

        // Apply replacements (case-insensitive)
        for rule in rules {
            let original = rule.original
            let replacementText = rule.replacementText

            // A self-expanding snippet ("my number is" -> "my number is
            // 847...") must not fire when the user spoke the expansion out
            // themselves; it would inject a second copy of the value.
            if replacementText.lowercased().hasPrefix(original.lowercased()),
                modifiedText.range(of: replacementText, options: .caseInsensitive) != nil
            {
                continue
            }

            let usesBoundaries = usesWordBoundaries(for: original)

            if usesBoundaries {
                // Lookarounds instead of \b so punctuation acts as a word boundary
                let escaped = NSRegularExpression.escapedPattern(for: original)
                let pattern = "(?<![a-zA-Z0-9])\(escaped)(?![a-zA-Z0-9])"
                if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                    let range = NSRange(modifiedText.startIndex..., in: modifiedText)
                    modifiedText = regex.stringByReplacingMatches(
                        in: modifiedText,
                        options: [],
                        range: range,
                        // User text, not a template: a replacement containing
                        // "$" (Venmo handles, prices) must come out literally.
                        withTemplate: NSRegularExpression.escapedTemplate(for: replacementText)
                    )
                }
            } else {
                // Fallback substring replace for non-spaced scripts
                modifiedText = modifiedText.replacingOccurrences(
                    of: original, with: replacementText, options: .caseInsensitive)
            }
        }

        return modifiedText
    }

    private func usesWordBoundaries(for text: String) -> Bool {
        // Returns false for languages without spaces (CJK, Thai), true for spaced languages
        let nonSpacedScripts: [ClosedRange<UInt32>] = [
            0x3040...0x309F,  // Hiragana
            0x30A0...0x30FF,  // Katakana
            0x4E00...0x9FFF,  // CJK Unified Ideographs
            0xAC00...0xD7AF,  // Hangul Syllables
            0x0E00...0x0E7F,  // Thai
        ]

        for scalar in text.unicodeScalars {
            for range in nonSpacedScripts {
                if range.contains(scalar.value) {
                    return false
                }
            }
        }

        return true
    }
}
