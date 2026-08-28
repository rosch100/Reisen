import SwiftUI
import Foundation

struct BookingPortalOpenCommandState {
    var url: URL?

    var canOpen: Bool { url != nil }
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
