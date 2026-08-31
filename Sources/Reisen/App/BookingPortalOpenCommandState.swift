import SwiftUI
import Foundation
import ReisenDomain

struct BookingPortalOpenCommandState {
    var url: URL?
    var cancellationURL: URL?
    var status: BookingStatus = .unknown
    var deadlines: [CancellationDeadline] = []
    var hasSessionWebView: Bool = false
    var requiresProviderSession: Bool

    var canOpen: Bool { url != nil }
    var canCancel: Bool {
        BookingPortalCancellation.presentation(
            cancellation: cancellationURL,
            open: url,
            status: status,
            deadlines: deadlines,
            now: Date(),
            hasSessionWebView: hasSessionWebView,
            requiresProviderSession: requiresProviderSession
        ) != .hidden
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
