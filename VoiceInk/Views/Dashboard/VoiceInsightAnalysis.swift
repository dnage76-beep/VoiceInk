import Foundation

/// Derived "your voice" insights: the things VoiceInk can say about *how* you
/// dictate, as opposed to how much. Everything here is computed on-device from
/// transcripts already stored locally; nothing is uploaded and nothing is
/// inferred by a model.
///
/// The two headline numbers, most-used word and fixes made by AI, both come out
/// of text the app already keeps: `Transcription.text` is what was heard and
/// `Transcription.enhancedText` is what was pasted, so the difference between
/// them is a record of what AI cleanup actually changed.
enum VoiceInsightAnalysis {

    // MARK: - Word frequency

    /// Words too common to be interesting. Without this, "the" wins forever and
    /// the card says nothing about the person using it.
    ///
    /// Deliberately shorter than a linguistic stopword list: words like "because"
    /// or "actually" are filler for a writer but genuinely characteristic of a
    /// speaker, and cutting them would flatten exactly the signal we want.
    private static let stopwords: Set<String> = [
        "a", "an", "and", "are", "as", "at", "be", "been", "but", "by", "can",
        "did", "do", "does", "for", "from", "had", "has", "have", "he", "her",
        "him", "his", "i", "if", "in", "is", "it", "its", "me", "my", "not",
        "of", "on", "or", "our", "she", "so", "than", "that", "the", "their",
        "them", "then", "there", "these", "they", "this", "to", "up", "us",
        "was", "we", "were", "what", "when", "which", "who", "will", "with",
        "would", "you", "your", "am", "how", "into", "out", "about", "over",
        "just", "get", "got", "go", "going", "want", "need", "make", "made",
        "one", "all", "also", "some", "any", "no", "yes", "okay", "ok",
    ]

    struct WordCount: Equatable, Identifiable {
        var id: String { word }
        let word: String
        let count: Int
    }

    /// Splits text into lowercased word tokens, discarding punctuation and
    /// anything that is not a real word (numbers, stray symbols).
    static func tokenize(_ text: String) -> [String] {
        text.lowercased()
            .split(whereSeparator: { !$0.isLetter && $0 != "'" })
            .map { token in
                // Trim possessives and stray quotes so "derek's" and "derek"
                // are not counted as two different words.
                String(token).trimmingCharacters(in: CharacterSet(charactersIn: "'"))
            }
            .filter { $0.count > 1 }
    }

    /// Most frequently spoken words across the given transcripts, excluding
    /// stopwords. Ties break alphabetically so the result is stable between
    /// refreshes rather than flickering between equally-common words.
    static func mostUsedWords(in texts: [String], limit: Int = 5) -> [WordCount] {
        var counts: [String: Int] = [:]

        for text in texts {
            for word in tokenize(text) where !stopwords.contains(word) {
                counts[word, default: 0] += 1
            }
        }

        return
            counts
            .map { WordCount(word: $0.key, count: $0.value) }
            .sorted { lhs, rhs in
                if lhs.count == rhs.count {
                    return lhs.word < rhs.word
                }
                return lhs.count > rhs.count
            }
            .prefix(limit)
            .map { $0 }
    }

    // MARK: - What AI cleanup changed

    /// One transcript's worth of raw text and the cleaned text that replaced it.
    struct EnhancementPair {
        let raw: String
        let enhanced: String
    }

    struct CorrectionSummary: Equatable {
        /// Words present in the raw transcript that cleanup removed or replaced.
        var wordsCorrected: Int = 0
        /// Sessions where cleanup changed something at all.
        var sessionsTouched: Int = 0
        /// The raw words most often replaced, best-effort.
        var mostCorrected: [WordCount] = []

        var totalFixes: Int { wordsCorrected }
        var hasData: Bool { wordsCorrected > 0 }
    }

    /// Counts what AI cleanup changed by comparing the words in the raw
    /// transcript against the words in the enhanced one.
    ///
    /// This is a multiset difference, not a true edit distance: for each word,
    /// any drop in its count from raw to enhanced is treated as a correction.
    /// That deliberately measures removals and substitutions (the filler words
    /// and misrecognitions users care about) while ignoring words cleanup
    /// *added*, since inserted punctuation and connectives are formatting rather
    /// than fixes. A reordering of the same words counts as zero, which is the
    /// intended behaviour.
    static func corrections(in pairs: [EnhancementPair]) -> CorrectionSummary {
        var summary = CorrectionSummary()
        var correctedCounts: [String: Int] = [:]

        for pair in pairs {
            let rawCounts = tally(tokenize(pair.raw))
            let enhancedCounts = tally(tokenize(pair.enhanced))

            var fixesThisSession = 0

            for (word, rawCount) in rawCounts {
                let survived = enhancedCounts[word] ?? 0
                let removed = rawCount - survived
                guard removed > 0 else { continue }

                fixesThisSession += removed

                // Stopwords are the bulk of what cleanup strips ("um" aside),
                // and listing "the" as your most-corrected word is noise. They
                // still count toward the total, they just do not headline.
                if !stopwords.contains(word) {
                    correctedCounts[word, default: 0] += removed
                }
            }

            if fixesThisSession > 0 {
                summary.wordsCorrected += fixesThisSession
                summary.sessionsTouched += 1
            }
        }

        summary.mostCorrected =
            correctedCounts
            .map { WordCount(word: $0.key, count: $0.value) }
            .sorted { lhs, rhs in
                if lhs.count == rhs.count {
                    return lhs.word < rhs.word
                }
                return lhs.count > rhs.count
            }
            .prefix(5)
            .map { $0 }

        return summary
    }

    private static func tally(_ words: [String]) -> [String: Int] {
        var counts: [String: Int] = [:]
        for word in words {
            counts[word, default: 0] += 1
        }
        return counts
    }
}
