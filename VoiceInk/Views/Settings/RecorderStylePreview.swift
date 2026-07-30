import SwiftUI

/// A small drawing of where each recorder appears on screen, so the choice
/// isn't made from the words "Notch" and "Mini" alone.
struct RecorderStylePreview: View {
    let style: RecorderPanelStyle
    var isSelected: Bool = false

    private let size = CGSize(width: 96, height: 58)

    var body: some View {
        ZStack {
            // Stand-in for the display.
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(AppTheme.Surface.subtle)
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(
                            isSelected ? AppTheme.Accent.primary : AppTheme.Border.card,
                            lineWidth: isSelected ? 1.5 : 1
                        )
                )

            // A sketch of a document on the screen, so the rectangle reads as
            // a display with work on it rather than an empty box, and the
            // recorder marker reads as sitting over that work.
            VStack(alignment: .leading, spacing: 3.5) {
                Capsule(style: .continuous)
                    .fill(Color.primary.opacity(0.16))
                    .frame(width: 30, height: 3.5)
                Capsule(style: .continuous)
                    .fill(Color.primary.opacity(0.10))
                    .frame(width: 56, height: 3)
                Capsule(style: .continuous)
                    .fill(Color.primary.opacity(0.10))
                    .frame(width: 48, height: 3)
                Capsule(style: .continuous)
                    .fill(Color.primary.opacity(0.10))
                    .frame(width: 22, height: 3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 14)
            .padding(.top, 6)

            switch style {
            case .notch:
                VStack {
                    NotchShape(topCornerRadius: 2, bottomCornerRadius: 5)
                        .fill(AppTheme.Accent.primary)
                        .frame(width: 44, height: 13)
                    Spacer()
                }
                .padding(.top, 1)
            case .mini:
                VStack {
                    Spacer()
                    Capsule()
                        .fill(AppTheme.Accent.primary)
                        .frame(width: 40, height: 13)
                    Spacer().frame(height: 9)
                }
            case .minimal:
                // Smaller than both, fully rounded, tucked under the menu bar.
                VStack {
                    Capsule()
                        .fill(AppTheme.Accent.primary)
                        .frame(width: 26, height: 9)
                    Spacer()
                }
                .padding(.top, 5)
            }
        }
        .frame(width: size.width, height: size.height)
        .accessibilityHidden(true)
    }
}

/// Segmented style chooser: each option shows its preview above its name.
struct RecorderStylePicker: View {
    @Binding var selection: RecorderPanelStyle

    var body: some View {
        HStack(spacing: 12) {
            ForEach(RecorderPanelStyle.allCases) { style in
                Button {
                    selection = style
                } label: {
                    VStack(spacing: 6) {
                        RecorderStylePreview(style: style, isSelected: selection == style)

                        Text(style.displayName)
                            .font(.system(size: 12, weight: selection == style ? .semibold : .regular))
                            .foregroundStyle(
                                selection == style ? AppTheme.Text.primary : AppTheme.Text.secondary)
                    }
                }
                .buttonStyle(.plain)
                .help(style.previewDescription)
                .accessibilityLabel(Text(style.displayName))
                .accessibilityHint(Text(style.previewDescription))
                .accessibilityAddTraits(selection == style ? [.isButton, .isSelected] : .isButton)
            }
        }
    }
}

extension RecorderPanelStyle {
    var previewDescription: String {
        switch self {
        case .notch:
            return String(localized: "Sits at the top of the screen, around the notch.")
        case .mini:
            return String(localized: "A small pill near the bottom of the screen.")
        case .minimal:
            return String(localized: "The smallest one. Just the voice animation at the top of the screen; click it to stop.")
        }
    }
}
