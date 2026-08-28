import SwiftUI
import ReisenDomain

/// Texte und Confirm-Dialoge für Buchung löschen / von Reise entfernen / Reise löschen.
public enum BookingTripActions {
    public static var removeFromTripTitle: String { L10n.string(.actionRemoveFromTrip) }
    public static var removeFromTripMessage: String { L10n.string(.tripRemoveFromTripHelp) }

    public static func bookingDeleteTitle(named title: String) -> String {
        L10n.format(.bookingDeleteConfirmTitleNamed, title)
    }

    public static func bookingDeleteMessage(showsSyncRestoreWarning: Bool) -> String {
        L10n.string(showsSyncRestoreWarning ? .bookingDeleteConfirmMessageSynced : .bookingDeleteConfirmMessage)
    }

    public static func tripDeleteTitle(named title: String?) -> String {
        guard let title, !title.isEmpty else {
            return L10n.string(.actionDeleteTripConfirm)
        }
        return L10n.format(.tripDeleteConfirmTitleNamed, title)
    }

    public static func tripDeleteMessage(bookingCount: Int) -> String {
        bookingCount == 0
            ? L10n.string(.tripDeleteConfirmMessageEmpty)
            : L10n.string(.tripDeleteConfirmMessageWithBookings)
    }
}

public struct BookingDeleteConfirmAlert: ViewModifier {
    @Binding var isPresented: Bool
    let bookingTitle: String
    let showsSyncRestoreWarning: Bool
    let onConfirm: () -> Void
    let onCancel: () -> Void

    public init(
        isPresented: Binding<Bool>,
        bookingTitle: String,
        showsSyncRestoreWarning: Bool,
        onConfirm: @escaping () -> Void,
        onCancel: @escaping () -> Void = {}
    ) {
        _isPresented = isPresented
        self.bookingTitle = bookingTitle
        self.showsSyncRestoreWarning = showsSyncRestoreWarning
        self.onConfirm = onConfirm
        self.onCancel = onCancel
    }

    public func body(content: Content) -> some View {
        content.alert(
            BookingTripActions.bookingDeleteTitle(named: bookingTitle),
            isPresented: $isPresented
        ) {
            Button(L10n.string(.commonDelete), role: .destructive, action: onConfirm)
            Button(L10n.string(.commonCancel), role: .cancel, action: onCancel)
        } message: {
            Text(BookingTripActions.bookingDeleteMessage(showsSyncRestoreWarning: showsSyncRestoreWarning))
        }
    }
}

public struct TripDeleteConfirmDialog: ViewModifier {
    @Binding var isPresented: Bool
    let tripTitle: String
    let bookingCount: Int
    let onKeepBookings: () -> Void
    let onDeleteBookings: () -> Void
    let onCancel: () -> Void

    public init(
        isPresented: Binding<Bool>,
        tripTitle: String,
        bookingCount: Int,
        onKeepBookings: @escaping () -> Void,
        onDeleteBookings: @escaping () -> Void,
        onCancel: @escaping () -> Void = {}
    ) {
        _isPresented = isPresented
        self.tripTitle = tripTitle
        self.bookingCount = bookingCount
        self.onKeepBookings = onKeepBookings
        self.onDeleteBookings = onDeleteBookings
        self.onCancel = onCancel
    }

    public func body(content: Content) -> some View {
        content.confirmationDialog(
            BookingTripActions.tripDeleteTitle(named: tripTitle),
            isPresented: $isPresented,
            titleVisibility: .visible
        ) {
            if bookingCount == 0 {
                Button(L10n.string(.commonDelete), role: .destructive, action: onKeepBookings)
            } else {
                Button(L10n.string(.tripDeleteWithBookings), role: .destructive, action: onDeleteBookings)
                Button(L10n.string(.tripDeleteKeepBookings), action: onKeepBookings)
            }
            Button(L10n.string(.commonCancel), role: .cancel, action: onCancel)
        } message: {
            Text(BookingTripActions.tripDeleteMessage(bookingCount: bookingCount))
        }
    }
}

public struct BookingTripConfirmDialogs: ViewModifier {
    @Binding var showDeleteConfirmation: Bool
    @Binding var showRemoveFromTripConfirmation: Bool
    let bookingTitle: String
    let showsSyncRestoreWarning: Bool
    let onConfirmDelete: () -> Void
    let onConfirmRemove: () -> Void
    let onCancelDelete: () -> Void
    let onCancelRemove: () -> Void

    public init(
        showDeleteConfirmation: Binding<Bool>,
        showRemoveFromTripConfirmation: Binding<Bool>,
        bookingTitle: String,
        showsSyncRestoreWarning: Bool,
        onConfirmDelete: @escaping () -> Void,
        onConfirmRemove: @escaping () -> Void,
        onCancelDelete: @escaping () -> Void = {},
        onCancelRemove: @escaping () -> Void = {}
    ) {
        _showDeleteConfirmation = showDeleteConfirmation
        _showRemoveFromTripConfirmation = showRemoveFromTripConfirmation
        self.bookingTitle = bookingTitle
        self.showsSyncRestoreWarning = showsSyncRestoreWarning
        self.onConfirmDelete = onConfirmDelete
        self.onConfirmRemove = onConfirmRemove
        self.onCancelDelete = onCancelDelete
        self.onCancelRemove = onCancelRemove
    }

    public func body(content: Content) -> some View {
        content
            .modifier(
                BookingDeleteConfirmAlert(
                    isPresented: $showDeleteConfirmation,
                    bookingTitle: bookingTitle,
                    showsSyncRestoreWarning: showsSyncRestoreWarning,
                    onConfirm: onConfirmDelete,
                    onCancel: onCancelDelete
                )
            )
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

public struct PersistFailureAlert: ViewModifier {
    @Binding var message: String?

    public init(message: Binding<String?>) {
        _message = message
    }

    public func body(content: Content) -> some View {
        content.alert(L10n.string(.tripAssignFailed), isPresented: Binding(
            get: { message != nil },
            set: { if !$0 { message = nil } }
        )) {
            Button(L10n.string(.commonOk), role: .cancel) { message = nil }
        } message: {
            if let message {
                Text(message)
            }
        }
    }
}

public extension View {
    func persistFailureAlert(message: Binding<String?>) -> some View {
        modifier(PersistFailureAlert(message: message))
    }

    func bookingDeleteConfirmAlert(
        isPresented: Binding<Bool>,
        bookingTitle: String,
        showsSyncRestoreWarning: Bool,
        onConfirm: @escaping () -> Void,
        onCancel: @escaping () -> Void = {}
    ) -> some View {
        modifier(
            BookingDeleteConfirmAlert(
                isPresented: isPresented,
                bookingTitle: bookingTitle,
                showsSyncRestoreWarning: showsSyncRestoreWarning,
                onConfirm: onConfirm,
                onCancel: onCancel
            )
        )
    }

    func tripDeleteConfirmDialog(
        isPresented: Binding<Bool>,
        tripTitle: String,
        bookingCount: Int,
        onKeepBookings: @escaping () -> Void,
        onDeleteBookings: @escaping () -> Void,
        onCancel: @escaping () -> Void = {}
    ) -> some View {
        modifier(
            TripDeleteConfirmDialog(
                isPresented: isPresented,
                tripTitle: tripTitle,
                bookingCount: bookingCount,
                onKeepBookings: onKeepBookings,
                onDeleteBookings: onDeleteBookings,
                onCancel: onCancel
            )
        )
    }

    func bookingTripConfirmDialogs(
        showDeleteConfirmation: Binding<Bool>,
        showRemoveFromTripConfirmation: Binding<Bool>,
        bookingTitle: String,
        showsSyncRestoreWarning: Bool,
        onConfirmDelete: @escaping () -> Void,
        onConfirmRemove: @escaping () -> Void,
        onCancelDelete: @escaping () -> Void = {},
        onCancelRemove: @escaping () -> Void = {}
    ) -> some View {
        modifier(
            BookingTripConfirmDialogs(
                showDeleteConfirmation: showDeleteConfirmation,
                showRemoveFromTripConfirmation: showRemoveFromTripConfirmation,
                bookingTitle: bookingTitle,
                showsSyncRestoreWarning: showsSyncRestoreWarning,
                onConfirmDelete: onConfirmDelete,
                onConfirmRemove: onConfirmRemove,
                onCancelDelete: onCancelDelete,
                onCancelRemove: onCancelRemove
            )
        )
    }
}
