import SwiftUI
import ReisenDomain

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

public extension View {
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
