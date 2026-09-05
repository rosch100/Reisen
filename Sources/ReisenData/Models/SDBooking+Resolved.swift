import Foundation
import ReisenDomain

public extension SDBooking {
    var resolvedCancellationDeadlines: [SDCancellationDeadline] { cancellationDeadlines ?? [] }
    var resolvedPassengers: [SDBookingPassenger] { passengers ?? [] }
    var resolvedGuestHints: [SDBookingGuestHint] { guestHints ?? [] }

    var domainCancellationDeadlines: [CancellationDeadline] {
        resolvedCancellationDeadlines.compactMap(DomainMapper.deadline(from:))
    }
}
