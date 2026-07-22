import Foundation
import ReisenDomain

/// Parses Booking.com Trip-XP GraphQL (`getTrips` + `singleTripTimeline`) into catalog drafts.
public struct BookingComTripsGraphQLParser: Sendable {
    public init() {}

    public func parseTripIDs(fromGetTripsJSON json: String) throws -> [String] {
        let list = try decodeGetTripsList(from: json)
        return list.trips.compactMap(\.id).filter { !$0.isEmpty }
    }

    public func parsePaginationToken(fromGetTripsJSON json: String) throws -> String? {
        let list = try decodeGetTripsList(from: json)
        let token = list.nextPageData?.paginationToken
        guard let token, !token.isEmpty else { return nil }
        return token
    }

    private func decodeGetTripsList(from json: String) throws -> GetTripsListPayload {
        let envelope: GetTripsEnvelope = try decodeGraphQL(json)
        guard let getTrips = envelope.data?.tripsQueries?.getTrips else {
            throw graphQLFailure(envelope.errors) ?? BookingComTripsGraphQLParserError.invalidJSON
        }
        if getTrips.typeName == "TripsListError" {
            throw BookingComTripsGraphQLParserError.tripsListError
        }
        let trips = getTrips.trips ?? []
        if trips.isEmpty, let failure = graphQLFailure(envelope.errors) {
            throw failure
        }
        return GetTripsListPayload(
            trips: trips,
            nextPageData: getTrips.nextPageData
        )
    }

    public func parseTimeline(from json: String) throws -> [ProviderBookingDraft] {
        let envelope: TimelineEnvelope = try decodeGraphQL(json)
        let timeline = envelope.data?.singleTripTimelineQueries?.singleTripTimeline
        let groups = timeline?.timelineGroups ?? []
        if groups.isEmpty, let failure = graphQLFailure(envelope.errors) {
            throw failure
        }

        let tripTitle = timeline?.trip?.title
        var bookings: [ProviderBookingDraft] = []
        for group in groups {
            for item in group.tripItems ?? [] {
                guard let reservation = item.reservation else { continue }
                if let draft = draft(from: reservation, tripTitle: tripTitle) {
                    bookings.append(draft)
                }
            }
        }

        return BookingComParsing.dedupeByExternalURL(bookings)
    }

    private func graphQLFailure(_ errors: [GraphQLErrorMessage]?) -> BookingComTripsGraphQLParserError? {
        guard let errors, !errors.isEmpty else { return nil }
        let message = errors.compactMap(\.message).filter { !$0.isEmpty }.joined(separator: "; ")
        return .graphQLErrors(message.isEmpty ? nil : message)
    }

    private func decodeGraphQL<T: Decodable>(_ json: String) throws -> T {
        guard let data = json.data(using: .utf8) else {
            throw BookingComTripsGraphQLParserError.invalidJSON
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw BookingComTripsGraphQLParserError.invalidJSON
        }
    }
}

public enum BookingComTripsGraphQLParserError: LocalizedError, Sendable, Equatable {
    case invalidJSON
    case graphQLErrors(String?)
    case tripsListError

    public var errorDescription: String? {
        switch self {
        case .invalidJSON:
            return "Booking.com GraphQL-Antwort konnte nicht gelesen werden."
        case .graphQLErrors(let detail):
            if let detail, !detail.isEmpty {
                return "Booking.com GraphQL meldete Fehler: \(detail)"
            }
            return "Booking.com GraphQL meldete Fehler."
        case .tripsListError:
            return "Booking.com Trip-Liste konnte nicht geladen werden."
        }
    }
}

private struct GetTripsListPayload {
    let trips: [GetTrip]
    let nextPageData: GetTripsNextPage?
}

private extension BookingComTripsGraphQLParser {
    struct MappedFields {
        var title: String?
        var locationFrom: String?
        var locationTo: String?
        var locationToAddress: String?
        var confirmationCode: String?
        var hotelOffsetSeconds: Int?
        var hotelCheckInMinutes: Int?
        var hotelCheckOutMinutes: Int?
        var flightDepartureOffsetSeconds: Int?
        var flightArrivalOffsetSeconds: Int?
        var deadlines: [CancellationDeadline] = []
        var airline: String?
        var passengerCount: Int?
    }

    func draft(from reservation: GraphQLReservation, tripTitle: String?) -> ProviderBookingDraft? {
        guard let externalUrl = BookingComParsing.absoluteBookingURL(
            reservation.bookingUrl ?? reservation.reservationDetailsURL
        ) else {
            return nil
        }

        let bookingType = bookingType(of: reservation)
        var fields = mappedFields(from: reservation, bookingType: bookingType, tripTitle: tripTitle)

        let startAt: Date
        let endAt: Date
        switch bookingType {
        case .hotel:
            // Hotels: nur Kalenderdatum aus ISO (Uhrzeit/TZ verwerfen).
            guard let startDay = BookingComParsing.dateOnly(fromISO: reservation.startDateTime),
                  let endDay = BookingComParsing.dateOnly(fromISO: reservation.endDateTime) else {
                return nil
            }
            startAt = startDay.date
            endAt = endDay.date
            fields.hotelOffsetSeconds = fields.hotelOffsetSeconds ?? startDay.offsetSeconds
            if fields.deadlines.isEmpty,
               let policyDeadline = deadline(
                from: reservation.policy,
                hotelOffsetSeconds: fields.hotelOffsetSeconds
               ) {
                fields.deadlines = [policyDeadline]
            }
        case .flight, .ferry, .other:
            // Flüge: Wanduhr als UTC + Offset; Normalizer macht Absolutzeit.
            guard let startStorage = BookingComParsing.wallClockStorage(fromISO: reservation.startDateTime),
                  let endStorage = BookingComParsing.wallClockStorage(fromISO: reservation.endDateTime) else {
                return nil
            }
            startAt = startStorage.wallClockAsUTC
            endAt = endStorage.wallClockAsUTC
            if bookingType == .flight || bookingType == .ferry {
                fields.flightDepartureOffsetSeconds = fields.flightDepartureOffsetSeconds ?? startStorage.offsetSeconds
                fields.flightArrivalOffsetSeconds = fields.flightArrivalOffsetSeconds ?? endStorage.offsetSeconds
            }
        }

        return ProviderBookingDraft(
            provider: .booking,
            bookingType: bookingType,
            title: fields.title,
            confirmationCode: fields.confirmationCode,
            externalUrl: externalUrl,
            startAt: startAt,
            endAt: endAt,
            locationFrom: fields.locationFrom,
            locationTo: fields.locationTo,
            locationToAddress: fields.locationToAddress,
            status: status(from: reservation.reservationStatus),
            deadlines: fields.deadlines,
            rateDetails: rateDetails(from: reservation, bookingType: bookingType, fields: fields),
            hotelOffsetSeconds: fields.hotelOffsetSeconds,
            hotelCheckInMinutes: fields.hotelCheckInMinutes,
            hotelCheckOutMinutes: fields.hotelCheckOutMinutes,
            flightDepartureOffsetSeconds: fields.flightDepartureOffsetSeconds,
            flightArrivalOffsetSeconds: fields.flightArrivalOffsetSeconds
        )
    }

    func bookingType(of reservation: GraphQLReservation) -> BookingType {
        let typeName = reservation.typeName ?? ""
        if typeName.contains("Flight") || reservation.verticalType == "FLIGHT" {
            return .flight
        }
        if typeName.contains("Accommodation") || reservation.verticalType == "ACCOMMODATION" {
            return .hotel
        }
        return .other
    }

    func mappedFields(
        from reservation: GraphQLReservation,
        bookingType: BookingType,
        tripTitle: String?
    ) -> MappedFields {
        var fields = MappedFields()
        switch bookingType {
        case .hotel:
            fields.title = reservation.propertyData?.name ?? tripTitle
            fields.locationTo = reservation.propertyData?.location?.city
            fields.locationToAddress = reservation.propertyData?.location?.address
            fields.confirmationCode = reservation.identifiers?.hotelReservationId
                ?? reservation.identifiers?.publicId
            if let checkInStart = reservation.checkIn?.start {
                fields.hotelOffsetSeconds = BookingComParsing.offsetSeconds(from: checkInStart)
                fields.hotelCheckInMinutes = BookingComParsing.clockMinutes(from: checkInStart)
            }
            if let checkOutEnd = reservation.checkOut?.end {
                fields.hotelCheckOutMinutes = BookingComParsing.clockMinutes(from: checkOutEnd)
            }
        case .flight:
            let route = flightRoute(reservation.flightComponents)
            fields.locationFrom = route.fromLabel
            fields.locationTo = route.toLabel
            if let fromCity = route.fromCity, let toCity = route.toCity {
                fields.title = "\(fromCity) → \(toCity)"
            } else {
                fields.title = tripTitle
            }
            fields.confirmationCode = BookingComParsing.nonEmpty(reservation.identifiers?.publicFacingIdentifier)
                ?? reservation.identifiers?.publicId
            fields.airline = route.airline
            fields.passengerCount = reservation.passengerCount
            fields.flightDepartureOffsetSeconds = BookingComParsing.offsetSeconds(from: reservation.startDateTime)
            fields.flightArrivalOffsetSeconds = BookingComParsing.offsetSeconds(from: reservation.endDateTime)
        case .ferry, .other:
            fields.title = tripTitle
            fields.confirmationCode = reservation.identifiers?.publicId
        }
        return fields
    }

    func rateDetails(
        from reservation: GraphQLReservation,
        bookingType: BookingType,
        fields: MappedFields
    ) -> BookingRateDetails? {
        if let price = reservation.price {
            return BookingRateDetails(
                totalPriceAmount: price.amount,
                totalPriceCurrency: price.currency,
                roomCount: bookingType == .hotel ? reservation.numOfRooms : nil,
                airline: fields.airline,
                passengerCount: fields.passengerCount
            )
        }
        if bookingType == .hotel, let rooms = reservation.numOfRooms {
            return BookingRateDetails(roomCount: rooms)
        }
        if fields.airline != nil || fields.passengerCount != nil {
            return BookingRateDetails(airline: fields.airline, passengerCount: fields.passengerCount)
        }
        return nil
    }

    func deadline(from policy: GraphQLPolicy?, hotelOffsetSeconds: Int?) -> CancellationDeadline? {
        guard let policy, policy.type?.uppercased() == "CANCELLATION" else { return nil }
        guard let offset = hotelOffsetSeconds else { return nil }
        guard let message = policy.message,
              let date = BookingComParsing.parseExclusiveGermanPolicyDate(
                in: message,
                offsetSeconds: offset
              ) else {
            return nil
        }
        let isFree = message.lowercased().contains("kostenlos")
            || (policy.name?.lowercased().contains("kostenlos") ?? false)
        return CancellationDeadline(
            deadlineAt: date,
            policyText: message,
            isStrict: true,
            isFreeCancellation: isFree,
            hotelOffsetSeconds: offset,
            cancellationFeeAmount: isFree ? 0 : nil
        )
    }

    func status(from raw: String?) -> BookingStatus {
        switch raw?.uppercased() {
        case "CONFIRMED":
            return .confirmed
        case "CANCELLED", "CANCELED":
            return .cancelled
        default:
            return .unknown
        }
    }

    func flightRoute(_ components: [GraphQLFlightComponent]?) -> (
        fromCity: String?,
        toCity: String?,
        fromLabel: String?,
        toLabel: String?,
        airline: String?
    ) {
        let parts = (components ?? []).compactMap(\.parts).flatMap { $0 }
        guard let first = parts.first, let last = parts.last else {
            return (nil, nil, nil, nil, nil)
        }
        let fromCity = first.startLocation?.location?.city
        let toCity = last.endLocation?.location?.city
        return (
            fromCity,
            toCity,
            placeLabel(city: fromCity, iata: first.startLocation?.iata),
            placeLabel(city: toCity, iata: last.endLocation?.iata),
            first.marketingCarrier?.code
        )
    }

    func placeLabel(city: String?, iata: String?) -> String? {
        switch (BookingComParsing.nonEmpty(city), BookingComParsing.nonEmpty(iata)) {
        case let (city?, iata?):
            return "\(city) (\(iata))"
        case let (city?, nil):
            return city
        case let (nil, iata?):
            return iata
        case (nil, nil):
            return nil
        }
    }
}

// MARK: - Codable DTOs

private struct GetTripsEnvelope: Decodable {
    let data: GetTripsData?
    let errors: [GraphQLErrorMessage]?
}

private struct GraphQLErrorMessage: Decodable {
    let message: String?
}

private struct GetTripsData: Decodable {
    let tripsQueries: GetTripsQueries?
}

private struct GetTripsQueries: Decodable {
    let getTrips: GetTripsResult?
}

private struct GetTripsResult: Decodable {
    let typeName: String?
    let trips: [GetTrip]?
    let nextPageData: GetTripsNextPage?

    enum CodingKeys: String, CodingKey {
        case typeName = "__typename"
        case trips
        case nextPageData
    }
}

private struct GetTrip: Decodable {
    let id: String?
}

private struct GetTripsNextPage: Decodable {
    let paginationToken: String?
}

private struct TimelineEnvelope: Decodable {
    let data: TimelineData?
    let errors: [GraphQLErrorMessage]?
}

private struct TimelineData: Decodable {
    let singleTripTimelineQueries: SingleTripTimelineQueries?
}

private struct SingleTripTimelineQueries: Decodable {
    let singleTripTimeline: SingleTripTimeline?
}

private struct SingleTripTimeline: Decodable {
    let trip: GraphQLTrip?
    let timelineGroups: [TripItemGroup]?
}

private struct GraphQLTrip: Decodable {
    let title: String?
}

private struct TripItemGroup: Decodable {
    let tripItems: [TripItem]?
}

private struct TripItem: Decodable {
    let reservation: GraphQLReservation?
}

private struct GraphQLReservation: Decodable {
    let typeName: String?
    let verticalType: String?
    let bookingUrl: String?
    let reservationDetailsURL: String?
    let startDateTime: String?
    let endDateTime: String?
    let reservationStatus: String?
    let numOfRooms: Int?
    let passengerCount: Int?
    let price: GraphQLPrice?
    let propertyData: GraphQLPropertyData?
    let identifiers: GraphQLIdentifiers?
    let flightComponents: [GraphQLFlightComponent]?
    let checkIn: GraphQLCheckWindow?
    let checkOut: GraphQLCheckWindow?
    let policy: GraphQLPolicy?

    enum CodingKeys: String, CodingKey {
        case typeName = "__typename"
        case verticalType
        case bookingUrl
        case reservationDetailsURL
        case startDateTime
        case endDateTime
        case reservationStatus
        case numOfRooms
        case passengerCount
        case price
        case propertyData
        case identifiers
        case flightComponents
        case checkIn
        case checkOut
        case policy
    }
}

private struct GraphQLPrice: Decodable {
    let amount: Double
    let currency: String
}

private struct GraphQLPropertyData: Decodable {
    let name: String?
    let location: GraphQLLocation?
}

private struct GraphQLLocation: Decodable {
    let city: String?
    let address: String?
}

private struct GraphQLIdentifiers: Decodable {
    let hotelReservationId: String?
    let publicId: String?
    let publicFacingIdentifier: String?
}

private struct GraphQLFlightComponent: Decodable {
    let parts: [GraphQLFlightPart]?
}

private struct GraphQLFlightPart: Decodable {
    let startLocation: GraphQLAirport?
    let endLocation: GraphQLAirport?
    let marketingCarrier: GraphQLCarrier?
    let flightNumber: String?
}

private struct GraphQLAirport: Decodable {
    let iata: String?
    let location: GraphQLLocation?
}

private struct GraphQLCarrier: Decodable {
    let code: String?
}

private struct GraphQLCheckWindow: Decodable {
    let start: String?
    let end: String?
}

private struct GraphQLPolicy: Decodable {
    let name: String?
    let type: String?
    let message: String?
}
