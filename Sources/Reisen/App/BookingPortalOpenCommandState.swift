import SwiftUI
import Foundation
import ReisenDomain
import ReisenData

struct BookingPortalOpenCommandState {
    var url: URL?
    var cancellationURL: URL?
    var status: BookingStatus = .unknown
    var deadlines: [CancellationDeadline] = []
    var hasSessionWebView: Bool = false
    var requiresProviderSession: Bool

    init(
        url: URL? = nil,
        cancellationURL: URL? = nil,
        status: BookingStatus = .unknown,
        deadlines: [CancellationDeadline] = [],
        hasSessionWebView: Bool = false,
        requiresProviderSession: Bool
    ) {
        self.url = url
        self.cancellationURL = cancellationURL
        self.status = status
        self.deadlines = deadlines
        self.hasSessionWebView = hasSessionWebView
        self.requiresProviderSession = requiresProviderSession
    }

    init(booking: SDBooking, hasSessionWebView: Bool) {
        self.init(
            url: booking.browserURL,
            cancellationURL: booking.cancellationBrowserURL,
            status: booking.status,
            deadlines: booking.domainCancellationDeadlines,
            hasSessionWebView: hasSessionWebView,
            requiresProviderSession: booking.cancellationRequiresProviderSession
        )
    }

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
