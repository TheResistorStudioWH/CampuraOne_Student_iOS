import SwiftUI
import PetaKitUIX

/// The same touch targets, contrast and text hierarchy across campus place cards
/// and route planning. Feature logic stays in the feature's own views.
struct MapPanelAction: View {
    let title: String
    let symbol: String
    var prominent = false
    var tint: Color = .accentColor
    let action: () -> Void
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Label(title, systemImage: symbol)
            .font(.subheadline.weight(.semibold))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.horizontal, 12)
            .foregroundStyle(prominent ? Color.white : tint)
            .background(prominent ? tint : tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
            .contentShape(RoundedRectangle(cornerRadius: 14))
            .opacity(isEnabled ? 1 : 0.45)
            .beButton(action)
            .buttonStyle(.plain)
    }
}

struct MapPanelIconButton: View {
    let title: String
    let symbol: String
    var tint: Color = .primary
    let action: () -> Void
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 16, weight: .semibold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(tint)
            .frame(width: 44, height: 44)
            .background(Color.primary.opacity(0.055), in: Circle())
            .contentShape(Circle())
            .beButton(action)
            .buttonStyle(.plain)
            .accessibilityLabel(title)
            .opacity(isEnabled ? 1 : 0.4)
    }
}

struct MapPanelMessage: View {
    let title: String
    let message: String
    let symbol: String
    var tint: Color = .accentColor

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.title3).foregroundStyle(tint)
                .frame(width: 30).frame(minHeight: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.headline)
                Text(message).font(.subheadline).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .mapPanelCard()
        .accessibilityElement(children: .combine)
    }
}

struct MapPanelSearchField: View {
    let prompt: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary).accessibilityHidden(true)
            TextField(prompt, text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .accessibilityLabel(prompt)
            if !text.isEmpty {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary).frame(width: 44, height: 44)
                    .contentShape(Rectangle())
                    .beButton { text = "" }
                    .buttonStyle(.plain)
                    .accessibilityLabel("清除筛选文字")
            }
        }
        .padding(.leading, 14).padding(.trailing, text.isEmpty ? 14 : 0)
        .frame(minHeight: 46)
        .background(Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct MapPanelCardStyle: ViewModifier {
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 18))
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(Color.primary.opacity(contrast == .increased ? 0.2 : 0.06), lineWidth: 1)
            }
    }
}

extension View {
    func mapPanelCard() -> some View { modifier(MapPanelCardStyle()) }
}
