import SwiftUI
import Foundation
import ReisenDomain

struct BookingPortalOpenCommandState {
    var url: URL?
    var cancellationURL: URL?
    var status: BookingStatus = .unknown

    var canOpen: Bool { url != nil }
    var canCancel: Bool {
        BookingPortalCancellation.isActionable(
            cancellation: cancellationURL,
            open: url,
            status: status
        )
    }
}

private struct BookingPortalOpenCommandStateKey: FocusedValueKey {
    typealias Value = BookingPortalOpenCommandState
}

extension FocusedValues {
    var bookingPortalOpenCommandState: BookingPortalOpenCommandState? {
        get { self[BookingPortalOpenCommandStateKey.self] }
        set { self[BookingPortalOpenCommandStateKey.self] = newValue }
    }
}
