import SwiftUI

/// A reusable info tip component that displays helpful information in a popover
struct InfoTip: View {
    // Content configuration
    var message: LocalizedStringKey
    var learnMoreLink: URL?

    // Appearance customization
    var iconName: String = "info.circle"
    var iconSize: Image.Scale = .medium
    var iconColor: Color = .primary
    var width: CGFloat = 280

    // State
    @State private var isShowingTip: Bool = false
    @State private var isHovering: Bool = false

    var body: some View {
        Image(systemName: iconName)
            .imageScale(iconSize)
            .foregroundColor(iconColor)
            .fontWeight(.semibold)
            // The icon is the click target, so it needs to look like one:
            // without this it reads as decoration and gets ignored.
            .opacity(isHovering || isShowingTip ? 1 : 0.55)
            .padding(5)
            .contentShape(Rectangle())
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.12)) {
                    isHovering = hovering
                }
            }
            .popover(isPresented: $isShowingTip) {
                VStack(alignment: .leading, spacing: 0) {
                    if learnMoreLink != nil {
                        (Text(message)
                            .foregroundColor(.secondary)
                            + Text(" ")
                            + Text("Learn more")
                            .foregroundColor(AppTheme.Accent.primary))
                            .font(.callout)
                    } else {
                        Text(message)
                            .font(.callout)
                            .foregroundColor(.secondary)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: width, alignment: .leading)
                .padding(14)
                // Only the link version is tappable; otherwise a stray click
                // inside the explanation just closes what you were reading.
                .modifier(InfoTipLinkTap(url: learnMoreLink))
            }
            .onTapGesture {
                isShowingTip.toggle()
            }
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(Text("More information"))
            .accessibilityValue(Text(message))
    }
}

/// Attaches the tap-to-open-link behavior only when there is a link, so a
/// plain explanation popover does not dismiss on every click inside it.
private struct InfoTipLinkTap: ViewModifier {
    let url: URL?

    func body(content: Content) -> some View {
        if let url {
            content.onTapGesture {
                NSWorkspace.shared.open(url)
            }
        } else {
            content
        }
    }
}

// MARK: - Convenience initializers

extension InfoTip {
    /// Creates an InfoTip with just a message
    init(_ message: LocalizedStringKey) {
        self.message = message
        self.learnMoreLink = nil
    }

    /// Creates an InfoTip with a dynamic string message
    init(_ message: String) {
        self.message = LocalizedStringKey(message)
        self.learnMoreLink = nil
    }

    /// Creates an InfoTip with a learn more link
    init(_ message: LocalizedStringKey, learnMoreURL: String) {
        self.message = message
        self.learnMoreLink = URL(string: learnMoreURL)
    }

    /// Creates an InfoTip with a dynamic string message and learn more link
    init(_ message: String, learnMoreURL: String) {
        self.message = LocalizedStringKey(message)
        self.learnMoreLink = URL(string: learnMoreURL)
    }
}
