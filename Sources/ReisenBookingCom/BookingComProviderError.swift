import Foundation

public enum BookingComProviderError: LocalizedError, Sendable, Equatable {
    case sessionNotEstablished
    case catalogNotFound
    case sessionTokensMissing

    public var errorDescription: String? {
        switch self {
        case .sessionNotEstablished:
            return "Es besteht noch keine Booking.com Session. Bitte zunächst anmelden."
        case .catalogNotFound:
            return "Booking.com-Katalog konnte nicht geladen werden."
        case .sessionTokensMissing:
            return "Booking.com Session-Token fehlt. Bitte erneut anmelden und synchronisieren."
        }
    }
}
