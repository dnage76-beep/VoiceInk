import SwiftUI

enum InsightTab: String, CaseIterable, Identifiable {
    case usage
    case voice

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .usage: return "Your usage"
        case .voice: return "Your voice"
        }
    }
}

/// Underlined tab bar. Deliberately not a segmented control: this is a page
/// switch, not a filter, and the underline reads as navigation.
struct InsightTabPicker: View {
    @Binding var selection: InsightTab

    @Namespace private var underline

    var body: some View {
        HStack(spacing: 22) {
            ForEach(InsightTab.allCases) { tab in
                tabButton(tab)
            }

            Spacer()
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppTheme.Border.subtle)
                .frame(height: 1)
        }
    }

    private func tabButton(_ tab: InsightTab) -> some View {
        let isSelected = selection == tab

        return Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                selection = tab
            }
        } label: {
            Text(tab.title)
                .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
                .foregroundStyle(isSelected ? AppTheme.Text.primary : AppTheme.Text.secondary)
                .padding(.bottom, 8)
                .overlay(alignment: .bottom) {
                    Group {
                        if isSelected {
                            Rectangle()
                                .fill(AppTheme.Accent.primary)
                                .frame(height: 2)
                                .matchedGeometryEffect(id: "underline", in: underline)
                        }
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
