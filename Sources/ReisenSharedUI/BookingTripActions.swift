import SwiftUI
import ReisenDomain

/// Texte und Confirm-Dialoge für Buchung löschen / von Reise entfernen.
public enum BookingTripActions {
    public static var deleteTitle: String { L10n.string(.actionDeleteEllipsis) }
    public static var removeFromTripTitle: String { L10n.string(.actionRemoveFromTrip) }
    public static var removeFromTripMessage: String { L10n.string(.tripRemoveFromTripHelp) }
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
                Button(L10n.string(.commonDelete), role: .destructive, action: onConfirmDelete)
                Button(L10n.string(.commonCancel), role: .cancel, action: onCancelDelete)
            }
            .confirmationDialog(
                BookingTripActions.removeFromTripTitle,
                isPresented: $showRemoveFromTripConfirmation,
                titleVisibility: .visible
            ) {
                Button(L10n.string(.commonRemove), role: .destructive, action: onConfirmRemove)
                Button(L10n.string(.commonCancel), role: .cancel, action: onCancelRemove)
            } message: {
                Text(BookingTripActions.removeFromTripMessage)
            }
    }
}

public extension View {
    func bookingDeleteConfirmDialog(
        showDeleteConfirmation: Binding<Bool>,
        onConfirmDelete: @escaping () -> Void,
        onCancelDelete: @escaping () -> Void = {}
    ) -> some View {
        confirmationDialog(
            BookingTripActions.deleteTitle,
            isPresented: showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(L10n.string(.commonDelete), role: .destructive, action: onConfirmDelete)
            Button(L10n.string(.commonCancel), role: .cancel, action: onCancelDelete)
        }
    }

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
