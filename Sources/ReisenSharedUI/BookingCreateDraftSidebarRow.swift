import SwiftUI

/// Provisorische Sidebar-Zeile während Create (Selection = Inspector-Objekt).
public struct BookingCreateDraftSidebarRow: View {
    public let title: String
    public let isSelected: Bool
    public let onSelect: () -> Void

    public init(title: String, isSelected: Bool, onSelect: @escaping () -> Void) {
        self.title = title
        self.isSelected = isSelected
        self.onSelect = onSelect
    }

    public var body: some View {
        Button(action: onSelect) {
            Label(title, systemImage: "plus.circle")
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
