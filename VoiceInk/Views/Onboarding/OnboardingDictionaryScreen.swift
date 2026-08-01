import SwiftData
import SwiftUI

/// Introduces the dictionary and captures a first personal entry or two
/// (phone number, email) so replacements exist before the first real
/// dictation instead of being a feature the user discovers weeks later.
struct OnboardingDictionaryScreen: View {
    let contentMaxWidth: CGFloat
    let onBack: () -> Void
    let onContinue: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Query private var existingReplacements: [WordReplacement]

    @State private var phoneNumber: String = ""
    @State private var email: String = ""

    var body: some View {
        OnboardingStepScreen(
            stage: .dictionary,
            contentMaxWidth: max(contentMaxWidth, 620)
        ) {
            VStack(spacing: 18) {
                explainerCard

                VStack(spacing: 10) {
                    entryRow(
                        spokenPhrase: "my number",
                        placeholder: "847-555-0123",
                        text: $phoneNumber
                    )
                    entryRow(
                        spokenPhrase: "my email",
                        placeholder: "you@example.com",
                        text: $email
                    )
                }

                Text("Both are optional, and everything lives on this Mac. Add more anytime under Dictionary.")
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.Text.muted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } bottomBar: {
            OnboardingBottomBar(
                leadingTitle: "Back",
                primaryTitle: "Continue",
                isPrimaryEnabled: true,
                onLeading: onBack,
                onPrimary: {
                    saveEntries()
                    onContinue()
                }
            )
        }
    }

    private var explainerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            exampleLine(
                icon: "textformat.abc",
                title: String(localized: "Spellings"),
                detail: String(
                    localized: "\"VoiceInk\" is already in there, so it never comes out as \"voice ink\".")
            )
            Divider()
            exampleLine(
                icon: "arrow.right.circle",
                title: String(localized: "Spoken shortcuts"),
                detail: String(
                    localized: "Say \"my number\" mid-sentence and VoiceInk types the real digits.")
            )
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppTheme.Surface.control.opacity(0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppTheme.Border.subtle, lineWidth: 1)
        )
    }

    private func exampleLine(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppTheme.Text.secondary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.Text.primary)
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.Text.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func entryRow(
        spokenPhrase: String,
        placeholder: String,
        text: Binding<String>
    ) -> some View {
        HStack(spacing: 12) {
            HStack(spacing: 5) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(AppTheme.Text.secondary)
                Text("\"\(spokenPhrase)\"")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.Text.primary)
            }
            .frame(width: 130, alignment: .leading)

            Image(systemName: "arrow.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(AppTheme.Text.muted)

            TextField(placeholder, text: text)
                .textFieldStyle(.roundedBorder)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.Surface.control.opacity(0.4))
        )
    }

    private func saveEntries() {
        let entries: [(spoken: String, typed: String)] = [
            ("my number", phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)),
            ("my email", email.trimmingCharacters(in: .whitespacesAndNewlines)),
        ]

        for entry in entries where !entry.typed.isEmpty {
            DictionaryService.addWordReplacement(
                original: entry.spoken,
                replacement: entry.typed,
                existing: Array(existingReplacements),
                context: modelContext
            )
        }
    }
}
