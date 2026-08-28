import Foundation

public enum BookingType: String, Codable, CaseIterable, Identifiable, Sendable {
    case flight
    case hotel
    case ferry
    case train
    case activity
    case carRental
    case other

    public var id: String { rawValue }

    /// Flug / Fähre / Bahn: Punkt-zu-Punkt, Ortszeit-Paar, FlightTimeNormalizer.
    public var usesFlightLikeSchedule: Bool {
        switch self {
        case .flight, .ferry, .train:
            return true
        case .hotel, .activity, .carRental, .other:
            return false
        }
    }

    /// GapKindClassifier: zwei Transporte → Lodging dazwischen.
    public var isTransport: Bool { usesFlightLikeSchedule }

    /// Check24/Booking.com/FlightTimeZoneAssigner: Offset-Autofill nur Flug/Fähre (IATA), nicht Bahn.
    public var supportsFlightOffsetAutofill: Bool {
        switch self {
        case .flight, .ferry:
            return true
        case .hotel, .train, .activity, .carRental, .other:
            return false
        }
    }

    /// UI-Label (Editor, Listen, Details).
    public var displayLabel: String {
        L10n.bookingTypeDisplay(self)
    }

    /// Fallback-Titel wenn `Booking.title` fehlt (Sync/Side-Effects, kompakte Listen).
    public var defaultDisplayTitle: String {
        rawValue.capitalized
    }
}
