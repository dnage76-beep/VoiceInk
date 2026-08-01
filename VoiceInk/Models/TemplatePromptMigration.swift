import Foundation

/// Refreshes seeded template prompts when a release improves their text.
///
/// Template prompts are copied into the user's prompt store the first time
/// they are seeded, so later releases changing `PromptTemplates` would never
/// reach an existing install. A stored prompt is upgraded only when its text
/// exactly matches an older shipped version; a prompt the user edited in any
/// way is never touched.
enum TemplatePromptMigration {
    static func refreshed(_ prompts: [CustomPrompt]) -> (prompts: [CustomPrompt], didChange: Bool) {
        var didChange = false
        let refreshed = prompts.map { prompt -> CustomPrompt in
            guard let priorTexts = priorVersions[prompt.id],
                priorTexts.contains(prompt.promptText),
                let template = PromptTemplates.seedPrompts.first(where: { $0.id == prompt.id }),
                template.promptText != prompt.promptText
            else {
                return prompt
            }

            didChange = true
            return template
        }

        return (refreshed, didChange)
    }

    /// Every text a template shipped with before the current one.
    private static let priorVersions: [UUID: [String]] = [
        PromptTemplates.emailPromptId: [emailV1]
    ]

    /// Email template through 1.2.5: no layout rules, so replies came out as
    /// one flat paragraph, and the "do not invent a closing" wording made
    /// models drop closings the user actually dictated.
    private static let emailV1 = """
        Polish the dictated speech in <TRANSCRIPT> into a clear, ready-to-send email body.

        # Rules
        - Use clear, friendly language and match a professional tone when the source is professional.
        - Use context only when it helps identify the thread, recipient, subject, requested reply, spelling, or references.
        - Add a greeting or closing only if the user dictated one, requested one, named the recipient or sender, or context clearly supports it.
        - Do not add placeholders such as "[Name]", "[Recipient]", "[Your Name]", or "Dear [Name]".
        - Use short paragraphs and lists for steps, options, asks, or action items when useful.
        - Do not invent a subject line, recipient, greeting, closing, deadline, promise, fact, opinion, or commentary.
        """
}
