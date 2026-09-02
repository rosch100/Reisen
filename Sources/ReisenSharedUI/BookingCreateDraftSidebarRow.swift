import SwiftUI
import ReisenDomain

/// Provisorische Sidebar-Zeile während Create (Selection = Inspector-Objekt).
public struct BookingCreateDraftSidebarRow: View {
    public let isSelected: Bool
    public let onSelect: () -> Void

    public init(isSelected: Bool, onSelect: @escaping () -> Void) {
        self.isSelected = isSelected
        self.onSelect = onSelect
    }

    public var body: some View {
        Button(action: onSelect) {
            Label(L10n.string(.editorCreateTitle), systemImage: "plus.circle")
                .font(.body.weight(.medium))
                .padding(.leading, 28)
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    isSelected
                        ? Color.accentColor.opacity(0.15)
                        : Color.clear
                )
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .accessibilityIdentifier(UITestingIdentifiers.bookingCreateDraftSidebar)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
