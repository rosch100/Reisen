import SwiftUI
import ReisenData
import ReisenDomain

/// Caption für Buchungen, deren Ende vor heute liegt.
public struct BookingElapsedLabel: View {
    private let isElapsed: Bool

    public init(for booking: SDBooking, now: Date = Date(), calendar: Calendar = .current) {
        isElapsed = booking.isElapsed(now: now, calendar: calendar)
    }

    public var body: some View {
        if isElapsed {
            Text(L10n.string(.bookingElapsed))
                .font(.caption2)
                .foregroundStyle(.orange)
        }
    }
}
