import Foundation

struct TranscriptionOutputFilter {
    // Noise annotations look like "[music]" or "(laughs)": a few letters,
    // nothing else. Matching any bracketed content deleted real output, most
    // visibly phone numbers the model formats as "(555) 123-4567".
    private static let hallucinationPatterns = [
        #"\[[A-Za-z' -]{1,30}\]"#,  // [music]
        #"\([A-Za-z' -]{1,30}\)"#,  // (laughs)
        #"\{[A-Za-z' -]{1,30}\}"#,  // {noise}
    ]

    static func filter(_ text: String) -> String {
        var filteredText = text

        // Remove <TAG>...</TAG> blocks
        let tagBlockPattern = #"<([A-Za-z][A-Za-z0-9:_-]*)[^>]*>[\s\S]*?</\1>"#
        if let regex = try? NSRegularExpression(pattern: tagBlockPattern) {
            let range = NSRange(filteredText.startIndex..., in: filteredText)
            filteredText = regex.stringByReplacingMatches(in: filteredText, options: [], range: range, withTemplate: "")
        }

        // Remove bracketed hallucinations
        for pattern in hallucinationPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let range = NSRange(filteredText.startIndex..., in: filteredText)
                filteredText = regex.stringByReplacingMatches(
                    in: filteredText, options: [], range: range, withTemplate: "")
            }
        }

        // Remove configured filler words. An empty list is naturally a no-op.
        for fillerWord in FillerWordManager.shared.fillerWords {
            let pattern = "\\b\(NSRegularExpression.escapedPattern(for: fillerWord))\\b[,.]?"
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(filteredText.startIndex..., in: filteredText)
                filteredText = regex.stringByReplacingMatches(
                    in: filteredText, options: [], range: range, withTemplate: "")
            }
        }

        // Clean whitespace
        filteredText = filteredText.replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
        filteredText = filteredText.trimmingCharacters(in: .whitespacesAndNewlines)

        return filteredText
    }
}
