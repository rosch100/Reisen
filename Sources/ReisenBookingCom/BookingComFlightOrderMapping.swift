import Foundation
import ReisenDomain

extension BookingComFlightOrderParser {
    func rateDetails(from order: FlightOrderEnvelope) -> BookingRateDetails? {
        guard let baggage = baggageSummary(from: order) else { return nil }
        return BookingRateDetails(baggageInfoRaw: baggage)
    }

    func firstSegment(_ order: FlightOrderEnvelope) -> FlightOrderSegment? {
        order.airOrder?.flightSegments?.first
    }

    func lastSegment(_ order: FlightOrderEnvelope) -> FlightOrderSegment? {
        order.airOrder?.flightSegments?.last
    }
}
