import SwiftUI

/// Texte und Confirm-Dialoge für Buchung löschen / von Reise entfernen.
public enum BookingTripActions {
    public static let deleteTitle = "Buchung wirklich löschen?"
    public static let removeFromTripTitle = "Buchung von Reise entfernen?"
    public static let removeFromTripMessage =
        "Die Buchung wird der Reise entzogen und erscheint unter „Offene Buchungen“."
}

public struct BookingTripConfirmDialogs: ViewModifier {
    @Binding var showDeleteConfirmation: Bool
    @Binding var showRemoveFromTripConfirmation: Bool
    let onConfirmDelete: () -> Void
    let onConfirmRemove: () -> Void
    let onCancelDelete: () -> Void
    let onCancelRemove: () -> Void

    public init(
        showDeleteConfirmation: Binding<Bool>,
        showRemoveFromTripConfirmation: Binding<Bool>,
        onConfirmDelete: @escaping () -> Void,
        onConfirmRemove: @escaping () -> Void,
        onCancelDelete: @escaping () -> Void = {},
        onCancelRemove: @escaping () -> Void = {}
    ) {
        _showDeleteConfirmation = showDeleteConfirmation
        _showRemoveFromTripConfirmation = showRemoveFromTripConfirmation
        self.onConfirmDelete = onConfirmDelete
        self.onConfirmRemove = onConfirmRemove
        self.onCancelDelete = onCancelDelete
        self.onCancelRemove = onCancelRemove
    }

    public func body(content: Content) -> some View {
        content
            .confirmationDialog(
                BookingTripActions.deleteTitle,
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Löschen", role: .destructive, action: onConfirmDelete)
                Button("Abbrechen", role: .cancel, action: onCancelDelete)
            }
            .confirmationDialog(
                BookingTripActions.removeFromTripTitle,
                isPresented: $showRemoveFromTripConfirmation,
                titleVisibility: .visible
            ) {
                Button("Entfernen", role: .destructive, action: onConfirmRemove)
                Button("Abbrechen", role: .cancel, action: onCancelRemove)
            } message: {
                Text(BookingTripActions.removeFromTripMessage)
            }
    }
}

public extension View {
    func bookingTripConfirmDialogs(
        showDeleteConfirmation: Binding<Bool>,
        showRemoveFromTripConfirmation: Binding<Bool>,
        onConfirmDelete: @escaping () -> Void,
        onConfirmRemove: @escaping () -> Void,
        onCancelDelete: @escaping () -> Void = {},
        onCancelRemove: @escaping () -> Void = {}
    ) -> some View {
        modifier(
            BookingTripConfirmDialogs(
                showDeleteConfirmation: showDeleteConfirmation,
                showRemoveFromTripConfirmation: showRemoveFromTripConfirmation,
                onConfirmDelete: onConfirmDelete,
                onConfirmRemove: onConfirmRemove,
                onCancelDelete: onCancelDelete,
                onCancelRemove: onCancelRemove
            )
        )
    }
}
