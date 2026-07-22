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
            flightDepartureOffsetSeconds: BookingComParsing.offsetSeconds(from: firstSegment(order)?.departureTimeTz),
            flightArrivalOffsetSeconds: BookingComParsing.offsetSeconds(from: lastSegment(order)?.arrivalTimeTz),
            passengers: passengers(from: order)
        )
    }

    public func parseDeadlines(from json: String) throws -> [CancellationDeadline] {
        try parse(from: json).deadlines
    }

    private func passengers(from order: FlightOrderEnvelope) -> [BookingPassenger] {
        guard let segment = firstSegment(order) else { return [] }
        let checked = segment.travellerCheckedLuggage ?? []
        let cabin = segment.travellerCabinLuggage ?? []

        // Booking.com uses travellerReference as stable identifier across the payload.
        // We build one BookingPassenger per traveller in the order response.
        let travellers = order.passengers ?? []

        return travellers.enumerated().map { index, traveller in
            let travellerReference = traveller.travellerReference ?? ""

            let allowances = baggageAllowances(
                travellerReference: travellerReference,
                checked: checked,
                cabin: cabin
            )

            return BookingPassenger(
                passengerNumber: index + 1,
                travellerType: traveller.travellerType,
                title: nil,
                givenName: traveller.firstName,
                familyName: traveller.lastName,
                secondFamilyName: nil,
                birthDate: nil,
                baggageAllowances: allowances
            )
        }
    }

    private func baggageAllowances(
        travellerReference: String,
        checked: [FlightTravellerLuggage],
        cabin: [FlightTravellerLuggage]
    ) -> [BaggageAllowance] {
        let checkedAllowances = checked
            .filter { $0.travellerReference == travellerReference }
            .compactMap { $0.luggageAllowance }

        let cabinAllowances = cabin
            .filter { $0.travellerReference == travellerReference }
            .compactMap { $0.luggageAllowance }

        var result: [BaggageAllowance] = []

        for allowance in checkedAllowances {
            result.append(BaggageAllowance(
                type: baggageType(from: allowance.luggageType),
                pieceCount: allowance.maxPiece,
                weightKg: allowance.maxWeightPerPiece.map(Double.init),
                sectionID: nil,
                airlineCode: nil,
                fromLabel: nil,
                toLabel: nil
            ))
        }

        for allowance in cabinAllowances {
            result.append(BaggageAllowance(
                type: baggageType(from: allowance.luggageType),
                pieceCount: allowance.maxPiece,
                weightKg: allowance.maxWeightPerPiece.map(Double.init),
                sectionID: nil,
                airlineCode: nil,
                fromLabel: nil,
                toLabel: nil
            ))
        }

        // Booking.com often marks an additional "personalItem" alongside HAND luggage.
        // We add it as a separate BaggageAllowance when present.
        if cabin.first(where: { $0.travellerReference == travellerReference })?.personalItem == true {
            result.append(BaggageAllowance(
                type: .personalItem,
                pieceCount: 1,
                weightKg: nil,
                sectionID: nil,
                airlineCode: nil,
                fromLabel: nil,
                toLabel: nil
            ))
        }

        return result
    }

    private func baggageType(from luggageType: String?) -> BaggageType {
        guard let luggageType else { return .unknown }
        switch luggageType.uppercased() {
        case "CHECKED_IN": return .checkedBag
        case "HAND": return .cabinBag
        case "PERSONAL_ITEM": return .personalItem
        default: return .unknown
        }
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

private extension BookingComFlightOrderParser {
    func deadlines(from options: FlightCancellationOptions?) -> [CancellationDeadline] {
        guard let options, options.cancellable == true else { return [] }
        var deadlines: [CancellationDeadline] = []
        for refund in options.refundOptions ?? [] {
            guard let raw = refund.deadlineAt ?? refund.expiresAt,
                  let date = BookingComParsing.parseISODateTime(raw) else { continue }
            deadlines.append(
                CancellationDeadline(
                    deadlineAt: date,
                    policyText: refund.description,
                    isStrict: true,
                    isFreeCancellation: options.isFullRefund == true || refund.isFullRefund == true,
                    cancellationFeeAmount: refund.feeAmount
                )
            )
        }
        return deadlines.sorted { $0.deadlineAt < $1.deadlineAt }
    }

    func rateDetails(from order: FlightOrderEnvelope) -> BookingRateDetails? {
        guard let baggage = baggageSummary(from: order) else { return nil }
        return BookingRateDetails(baggageInfoRaw: baggage)
    }

    func baggageSummary(from order: FlightOrderEnvelope) -> String? {
        guard let segment = firstSegment(order) else { return nil }
        var parts: [String] = []

        if let checked = segment.travellerCheckedLuggage?.first?.luggageAllowance {
            parts.append(formatAllowance(checked, label: "Aufgabe"))
        }
        if let cabin = segment.travellerCabinLuggage?.first?.luggageAllowance {
            parts.append(formatAllowance(cabin, label: "Hand"))
        }

        if parts.isEmpty, let luggage = order.luggageBySegment?.first?.first?.luggageAllowance {
            for item in luggage {
                let label: String
                switch item.luggageType?.uppercased() {
                case "CHECKED_IN":
                    label = "Aufgabe"
                case "HAND":
                    label = "Hand"
                case "PERSONAL_ITEM":
                    label = "Personal"
                default:
                    label = item.luggageType ?? "Gepäck"
                }
                parts.append(formatAllowance(item, label: label))
            }
        }

        let unique = parts.filter { !$0.isEmpty }
        return unique.isEmpty ? nil : unique.joined(separator: "; ")
    }

    func formatAllowance(_ allowance: FlightLuggageAllowance, label: String) -> String {
        var bits: [String] = [label]
        if let pieces = allowance.maxPiece {
            bits.append("\(pieces)×")
        }
        if let weight = allowance.maxWeightPerPiece {
            let unit = allowance.massUnit ?? "KG"
            bits.append("\(weight)\(unit)")
        }
        return bits.joined(separator: " ")
    }

    func firstSegment(_ order: FlightOrderEnvelope) -> FlightOrderSegment? {
        order.airOrder?.flightSegments?.first
    }

    func lastSegment(_ order: FlightOrderEnvelope) -> FlightOrderSegment? {
        order.airOrder?.flightSegments?.last
    }
}

private struct FlightOrderEnvelope: Decodable {
    let cancellationOptions: FlightCancellationOptions?
    let airOrder: FlightAirOrder?
    let luggageBySegment: [[FlightLuggageByTraveller]]?
    let passengers: [FlightPassenger]?
}

private struct FlightCancellationOptions: Decodable {
    let cancellable: Bool?
    let isFullRefund: Bool?
    let refundOptions: [FlightRefundOption]?
}

private struct FlightRefundOption: Decodable {
    let deadlineAt: String?
    let expiresAt: String?
    let description: String?
    let isFullRefund: Bool?
    let feeAmount: Double?
}

private struct FlightAirOrder: Decodable {
    let flightSegments: [FlightOrderSegment]?
}

private struct FlightOrderSegment: Decodable {
    let departureTimeTz: String?
    let arrivalTimeTz: String?
    let travellerCheckedLuggage: [FlightTravellerLuggage]?
    let travellerCabinLuggage: [FlightTravellerLuggage]?
}

private struct FlightTravellerLuggage: Decodable {
    let travellerReference: String?
    let luggageAllowance: FlightLuggageAllowance?
    let personalItem: Bool?
}

private struct FlightLuggageByTraveller: Decodable {
    let luggageAllowance: [FlightLuggageAllowance]?
}

private struct FlightLuggageAllowance: Decodable {
    let luggageType: String?
    let maxPiece: Int?
    let maxWeightPerPiece: Int?
    let massUnit: String?
}

private struct FlightPassenger: Decodable {
    let travellerReference: String?
    let firstName: String?
    let lastName: String?
    let type: String?
    let gender: String?

    var travellerType: TravellerType {
        switch (type ?? "").uppercased() {
        case "ADULT": return .adult
        case "CHILD": return .child
        case "INFANT": return .infant
        default: return .unknown
        }
    }
}
