import Foundation

public extension SDBooking {
    var resolvedCancellationDeadlines: [SDCancellationDeadline] { cancellationDeadlines ?? [] }
    var resolvedPassengers: [SDBookingPassenger] { passengers ?? [] }
    var resolvedGuestHints: [SDBookingGuestHint] { guestHints ?? [] }
}
