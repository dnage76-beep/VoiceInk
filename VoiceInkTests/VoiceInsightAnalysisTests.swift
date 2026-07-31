import Foundation
import Testing

@testable import VoiceInk

/// The word-level insights are derived from transcript text, so their failure
/// mode is quiet: a wrong number still renders beautifully. These pin the rules.
struct VoiceInsightWordTests {

    @Test func tokenizerDropsPunctuationAndCase() {
        let tokens = VoiceInsightAnalysis.tokenize("Hello, world! Hello again.")
        #expect(tokens == ["hello", "world", "hello", "again"])
    }

    @Test func tokenizerKeepsContractionsIntact() {
        let tokens = VoiceInsightAnalysis.tokenize("I don't think it's ready")
        #expect(tokens.contains("don't"))
        #expect(tokens.contains("it's"))
    }

    @Test func tokenizerDropsSingleLettersAndNumbers() {
        // "a" and "5" carry no signal for a word-frequency card.
        let tokens = VoiceInsightAnalysis.tokenize("a b 42 rivet")
        #expect(tokens == ["rivet"])
    }

    @Test func possessivesFoldIntoTheBareWord() {
        let tokens = VoiceInsightAnalysis.tokenize("'quoted'")
        #expect(tokens == ["quoted"])
    }

    @Test func mostUsedWordSkipsStopwords() {
        // "the" appears most, but it is not an insight about the speaker.
        let texts = ["the the the the rivet rivet fixture"]
        let result = VoiceInsightAnalysis.mostUsedWords(in: texts)
        #expect(result.first?.word == "rivet")
        #expect(result.first?.count == 2)
    }

    @Test func mostUsedWordAggregatesAcrossTranscripts() {
        let texts = ["rivet fixture", "rivet placard", "rivet"]
        let result = VoiceInsightAnalysis.mostUsedWords(in: texts)
        #expect(result.first?.word == "rivet")
        #expect(result.first?.count == 3)
    }

    /// Equal counts must not reorder between refreshes, or the card visibly
    /// flickers between two words for no reason the user can see.
    @Test func tiesBreakAlphabeticallyForStableOrdering() {
        let texts = ["zebra apple"]
        let result = VoiceInsightAnalysis.mostUsedWords(in: texts)
        #expect(result.map(\.word) == ["apple", "zebra"])
    }

    @Test func emptyInputProducesNoWords() {
        #expect(VoiceInsightAnalysis.mostUsedWords(in: []).isEmpty)
        #expect(VoiceInsightAnalysis.mostUsedWords(in: ["", "   "]).isEmpty)
    }

    @Test func limitIsRespected() {
        let texts = ["alpha beta gamma delta epsilon zeta eta"]
        let result = VoiceInsightAnalysis.mostUsedWords(in: texts, limit: 3)
        #expect(result.count == 3)
    }
}

/// The "fixes made by AI" number compares what was heard against what was
/// pasted. It is the most visible derived number on the page.
struct VoiceInsightCorrectionTests {

    private func pair(_ raw: String, _ enhanced: String) -> VoiceInsightAnalysis.EnhancementPair {
        VoiceInsightAnalysis.EnhancementPair(raw: raw, enhanced: enhanced)
    }

    @Test func identicalTextMeansNoFixes() {
        let result = VoiceInsightAnalysis.corrections(in: [pair("ship the rivet", "ship the rivet")])
        #expect(result.wordsCorrected == 0)
        #expect(result.sessionsTouched == 0)
        #expect(result.hasData == false)
    }

    @Test func removedFillerCountsAsAFix() {
        let result = VoiceInsightAnalysis.corrections(in: [pair("um ship the rivet", "ship the rivet")])
        #expect(result.wordsCorrected == 1)
        #expect(result.sessionsTouched == 1)
    }

    @Test func repeatedFillerCountsEachOccurrence() {
        let result = VoiceInsightAnalysis.corrections(in: [pair("um um um ship", "ship")])
        #expect(result.wordsCorrected == 3)
    }

    @Test func substitutionCountsAsAFix() {
        let result = VoiceInsightAnalysis.corrections(in: [pair("ship the rivit", "ship the rivet")])
        #expect(result.wordsCorrected == 1)
        #expect(result.mostCorrected.first?.word == "rivit")
    }

    /// Words cleanup *adds* are formatting, not corrections, so they must not
    /// inflate the count.
    @Test func addedWordsAreNotCountedAsFixes() {
        let result = VoiceInsightAnalysis.corrections(in: [pair("ship rivet", "please ship the rivet now")])
        #expect(result.wordsCorrected == 0)
    }

    /// Reordering the same words is a rewrite, not a fix.
    @Test func reorderingAloneIsNotAFix() {
        let result = VoiceInsightAnalysis.corrections(in: [pair("rivet the ship", "ship the rivet")])
        #expect(result.wordsCorrected == 0)
    }

    @Test func fixesAccumulateAcrossSessions() {
        let result = VoiceInsightAnalysis.corrections(in: [
            pair("um ship", "ship"),
            pair("uh rivet", "rivet"),
        ])
        #expect(result.wordsCorrected == 2)
        #expect(result.sessionsTouched == 2)
    }

    /// Stopwords still count toward the total but must not headline the
    /// most-corrected card, where "the" would win permanently.
    @Test func stopwordsCountButDoNotHeadline() {
        let result = VoiceInsightAnalysis.corrections(in: [pair("the the rivit ship", "ship")])
        #expect(result.wordsCorrected == 3)
        #expect(result.mostCorrected.map(\.word) == ["rivit"])
    }

    @Test func emptyInputIsSafe() {
        let result = VoiceInsightAnalysis.corrections(in: [])
        #expect(result.wordsCorrected == 0)
        #expect(result.mostCorrected.isEmpty)
    }
}

/// App categorisation drives the Desktop usage card. Bundle IDs vary by channel
/// and vendor, so matching is by keyword and must not misfile the common ones.
struct DictationCategoryTests {

    @Test func recognisesTheCommonApps() {
        #expect(DictationCategory.category(forBundleID: "com.apple.mail") == .email)
        #expect(DictationCategory.category(forBundleID: "com.tinyspeck.slackmacgap") == .workMessages)
        #expect(DictationCategory.category(forBundleID: "com.apple.MobileSMS") == .other)
        #expect(DictationCategory.category(forBundleID: "com.apple.dt.Xcode") == .code)
        #expect(DictationCategory.category(forBundleID: "com.openai.chat") == .aiPrompts)
        #expect(DictationCategory.category(forBundleID: "md.obsidian") == .documents)
    }

    @Test func matchesReleaseChannelVariants() {
        // Beta and canary builds append to the bundle ID.
        #expect(DictationCategory.category(forBundleID: "com.google.Chrome.beta") == .browsing)
        #expect(DictationCategory.category(forBundleID: "com.microsoft.VSCodeInsiders") == .code)
    }

    @Test func matchingIsCaseInsensitive() {
        #expect(DictationCategory.category(forBundleID: "COM.APPLE.SAFARI") == .browsing)
    }

    @Test func unknownAndMissingFallBackToOther() {
        #expect(DictationCategory.category(forBundleID: "com.example.unknownapp") == .other)
        #expect(DictationCategory.category(forBundleID: nil) == .other)
        #expect(DictationCategory.category(forBundleID: "") == .other)
    }

    /// Claude and ChatGPT must read as AI prompts even though Claude's desktop
    /// bundle ID also contains a vendor name that appears nowhere else.
    @Test func aiAppsBeatOtherRules() {
        #expect(DictationCategory.category(forBundleID: "com.anthropic.claudefordesktop") == .aiPrompts)
    }
}

struct DashboardAppUsageSummaryTests {

    @Test func emptySummaryHasNoData() {
        #expect(DashboardAppUsageSummary.empty.hasData == false)
        #expect(DashboardAppUsageSummary.empty.share(of: .email) == 0)
    }

    @Test func shareIsComputedAgainstAttributedWords() {
        let summary = DashboardAppUsageSummary(
            apps: [
                AppDictationUsage(
                    bundleID: "com.apple.mail", name: "Mail", category: .email,
                    sessionCount: 1, wordCount: 75
                ),
                AppDictationUsage(
                    bundleID: "com.apple.dt.Xcode", name: "Xcode", category: .code,
                    sessionCount: 1, wordCount: 25
                ),
            ],
            categories: [
                CategoryDictationUsage(category: .email, sessionCount: 1, wordCount: 75),
                CategoryDictationUsage(category: .code, sessionCount: 1, wordCount: 25),
            ]
        )

        #expect(summary.share(of: .email) == 0.75)
        #expect(summary.share(of: .code) == 0.25)
        #expect(summary.distinctAppCount == 2)
        #expect(summary.attributedSessionCount == 2)
    }
}
