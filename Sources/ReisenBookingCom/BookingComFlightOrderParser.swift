import Foundation
import ReisenDomain

public struct BookingComFlightOrderParseResult: Equatable, Sendable {
    public var deadlines: [CancellationDeadline]
    public var rateDetails: BookingRateDetails?
    public var flightDepartureOffsetSeconds: Int?
    public var flightArrivalOffsetSeconds: Int?
    public var passengers: [BookingPassenger]

    public init(
        deadlines: [CancellationDeadline] = [],
        rateDetails: BookingRateDetails? = nil,
        flightDepartureOffsetSeconds: Int? = nil,
        flightArrivalOffsetSeconds: Int? = nil,
        passengers: [BookingPassenger] = []
    ) {
        self.deadlines = deadlines
        self.rateDetails = rateDetails
        self.flightDepartureOffsetSeconds = flightDepartureOffsetSeconds
        self.flightArrivalOffsetSeconds = flightArrivalOffsetSeconds
        self.passengers = passengers
    }
}

/// Parst Booking.com Flights Order-API (Storno, Gepäck, TZ-Offsets).
public struct BookingComFlightOrderParser: Sendable {
    public init() {}

    public func parse(from json: String) throws -> BookingComFlightOrderParseResult {
        guard let data = json.data(using: .utf8) else {
            throw BookingComFlightOrderParserError.invalidJSON
        }
        let order: FlightOrderEnvelope
        do {
            order = try JSONDecoder().decode(FlightOrderEnvelope.self, from: data)
        } catch {
            throw BookingComFlightOrderParserError.invalidJSON
        }

        return BookingComFlightOrderParseResult(
            deadlines: deadlines(from: order.cancellationOptions),
            rateDetails: rateDetails(from: order),
            flightDepartureOffsetSeconds: ISODateTime.offsetSeconds(from: firstSegment(order)?.departureTimeTz),
            flightArrivalOffsetSeconds: ISODateTime.offsetSeconds(from: lastSegment(order)?.arrivalTimeTz),
            passengers: passengers(from: order)
        )
    }

    public func parseDeadlines(from json: String) throws -> [CancellationDeadline] {
        try parse(from: json).deadlines
    }
}

public enum BookingComFlightOrderParserError: LocalizedError, Sendable {
    case invalidJSON

    public var errorDescription: String? {
        switch self {
        case .invalidJSON:
            return "Booking.com Flug-Order-Antwort konnte nicht gelesen werden."
        }
    }
}
