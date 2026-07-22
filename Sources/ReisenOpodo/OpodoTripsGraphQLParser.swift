import Foundation
import ReisenDomain

/// Parses Opodo GraphQL `getTrips` into catalog drafts (HAR: My Trips / secure area).
public struct OpodoTripsGraphQLParser: Sendable {
    public init() {}

    public func parseTrips(from json: String) throws -> [ProviderBookingDraft] {
        guard let data = json.data(using: .utf8) else {
            throw OpodoTripsGraphQLParserError.invalidJSON
        }

        let envelope: Envelope
        do {
            envelope = try JSONDecoder().decode(Envelope.self, from: data)
        } catch {
            throw OpodoTripsGraphQLParserError.invalidJSON
        }

        let wrappers = envelope.data?.getTrips?.trips ?? []
        var bookings: [ProviderBookingDraft] = []
        for wrapper in wrappers {
            guard let trip = wrapper.trip else { continue }
            if let draft = draft(from: trip) {
                bookings.append(draft)
            }
        }

        var byURL: [String: ProviderBookingDraft] = [:]
        for booking in bookings {
            guard let url = booking.externalUrl else { continue }
            byURL[url] = booking
        }
        return Array(byURL.values).sorted { $0.startAt < $1.startAt }
    }
}

public enum OpodoTripsGraphQLParserError: LocalizedError, Sendable {
    case invalidJSON

    public var errorDescription: String? {
        switch self {
        case .invalidJSON:
            return "Opodo GraphQL-Antwort konnte nicht gelesen werden."
        }
    }
}

/// SSOT for Opodo `getTrips` request body (session-bound catalog).
public enum OpodoGetTripsQuery {
    /// Katalogfelder aus HAR `getTrips` UPCOMING (inkl. Adresse, Zimmer, Carrier, IATA).
    public static let query = """
    query getTrips($filter: TripListFilter!, $maxNumBookingsByPage: Int!, $offsetPage: Int!) {
      getTrips(
        filter: $filter
        pagination: {
          maxNumBookingsByPage: $maxNumBookingsByPage
          offsetPage: $offsetPage
        }
      ) {
        trips {
          trip {
            id
            bookingStatus
            bookingProductStatus
            tdToken
            price { amount currency }
            travellers { travellerType }
            itinerary {
              departureDate
              arrivalDate
              origin { cityName iata }
              destination { cityName iata }
              legs {
                sections {
                  pnr
                  flightCode
                  carrier { name }
                  departure { iata name }
                  arrival { iata name }
                }
              }
            }
            accommodationBooking {
              id
              city
              bookingStatus
              accommodationName
              address
              postalCode
              countryCode
              checkInDate
              checkOutDate
              checkIn
              checkOut
              boardType
              numberOfRooms
              numberOfAdults
              numberOfChildren
              bookingRooms { roomDescription }
            }
          }
        }
      }
    }
    """

    public static func requestBody(
        filter: String,
        maxNumBookingsByPage: Int,
        offsetPage: Int
    ) throws -> Data {
        let payload: [String: Any] = [
            "query": query,
            "operationName": "getTrips",
            "variables": [
                "filter": filter,
                "maxNumBookingsByPage": maxNumBookingsByPage,
                "offsetPage": offsetPage,
            ],
        ]
        return try JSONSerialization.data(withJSONObject: payload, options: [])
    }
}

private extension OpodoTripsGraphQLParser {
    func draft(from trip: GraphQLTrip) -> ProviderBookingDraft? {
        guard let tdToken = trip.tdToken, !tdToken.isEmpty else { return nil }
        let externalUrl = "https://www.opodo.de/travel/secure/#tripdetails/td=\(tdToken)"
        let rateDetails = rateDetails(from: trip.price)
        if let hotel = trip.accommodationBooking {
            return draftHotel(
                trip: trip,
                hotel: hotel,
                externalUrl: externalUrl,
                rateDetails: rateDetails
            )
        }

        if let itinerary = trip.itinerary {
            return draftFlight(
                trip: trip,
                itinerary: itinerary,
                externalUrl: externalUrl,
                rateDetails: rateDetails
            )
        }

        return nil
    }

    func draftHotel(
        trip: GraphQLTrip,
        hotel: GraphQLAccommodation,
        externalUrl: String,
        rateDetails: BookingRateDetails?
    ) -> ProviderBookingDraft? {
        guard let rawStart = dateFromEpochMillis(hotel.checkInDate),
              let rawEnd = dateFromEpochMillis(hotel.checkOutDate) else {
            return nil
        }

        // Hotels: nur Kalenderdatum — Uhrzeit/TZ verwerfen.
        let startAt = HotelStayDate.dateOnly(fromStoredOrParsed: rawStart)
        let endAt = HotelStayDate.dateOnly(fromStoredOrParsed: rawEnd)
        let adults = hotel.numberOfAdults ?? 0
        let children = hotel.numberOfChildren ?? 0
        let guestCount = (adults + children) > 0 ? (adults + children) : nil
        let board = boardType(from: hotel.boardType)
        let roomCategory = roomCategory(from: hotel.bookingRooms)
        let roomItems = roomItems(from: hotel.bookingRooms)

        var details = rateDetails
        if var existing = details {
            existing.boardType = board
            existing.roomCount = hotel.numberOfRooms
            existing.guestCount = guestCount
            existing.includedBreakfast = board == .breakfastIncluded
            existing.roomCategory = roomCategory
            if !roomItems.isEmpty {
                existing.roomItems = roomItems
            }
            details = existing
        } else if hotel.boardType != nil || hotel.numberOfRooms != nil || roomCategory != nil {
            details = BookingRateDetails(
                roomCategory: roomCategory,
                boardType: board,
                includedBreakfast: board == .breakfastIncluded,
                guestCount: guestCount,
                roomCount: hotel.numberOfRooms,
                roomItems: roomItems
            )
        }

        return ProviderBookingDraft(
            provider: .opodo,
            bookingType: .hotel,
            title: hotel.accommodationName,
            confirmationCode: hotel.id ?? trip.id,
            externalUrl: externalUrl,
            startAt: startAt,
            endAt: endAt,
            locationFrom: nil,
            locationTo: hotel.city,
            locationToAddress: hotelAddress(
                street: hotel.address,
                postalCode: hotel.postalCode,
                city: hotel.city,
                countryCode: hotel.countryCode
            ),
            status: status(bookingStatus: hotel.bookingStatus ?? trip.bookingStatus, productStatus: trip.bookingProductStatus),
            rateDetails: details,
            hotelCheckInMinutes: parseClockMinutes(hotel.checkIn),
            hotelCheckOutMinutes: parseClockMinutes(hotel.checkOut)
        )
    }

    func draftFlight(
        trip: GraphQLTrip,
        itinerary: GraphQLItinerary,
        externalUrl: String,
        rateDetails: BookingRateDetails?
    ) -> ProviderBookingDraft? {
        guard let startAt = dateFromEpochMillis(itinerary.departureDate),
              let endAt = dateFromEpochMillis(itinerary.arrivalDate) else {
            return nil
        }

        let fromCity = itinerary.origin?.cityName
        let toCity = itinerary.destination?.cityName
        let sections = itinerary.legs?
            .compactMap(\.sections)
            .flatMap { $0 } ?? []
        let firstSection = sections.first

        let fromIata = firstSection?.departure?.iata ?? itinerary.origin?.iata
        let toIata = firstSection?.arrival?.iata ?? itinerary.destination?.iata
        let from = cityWithIata(city: fromCity, iata: fromIata)
        let to = cityWithIata(city: toCity, iata: toIata)

        let title: String? = {
            if let fromCity, let toCity {
                return "\(fromCity) → \(toCity)"
            }
            return toCity ?? fromCity
        }()

        let pnr = sections.compactMap(\.pnr).first
        let airline = firstSection?.carrier?.name
        let passengerCount = trip.travellers.flatMap { $0.isEmpty ? nil : $0.count }

        var details = rateDetails
        if var existing = details {
            existing.airline = airline
            existing.passengerCount = passengerCount
            details = existing
        } else if airline != nil || passengerCount != nil {
            details = BookingRateDetails(airline: airline, passengerCount: passengerCount)
        }

        return ProviderBookingDraft(
            provider: .opodo,
            bookingType: .flight,
            title: title,
            confirmationCode: pnr ?? trip.id,
            externalUrl: externalUrl,
            startAt: startAt,
            endAt: endAt,
            locationFrom: from,
            locationTo: to,
            locationFromAddress: nonEmpty(firstSection?.departure?.name),
            locationToAddress: nonEmpty(firstSection?.arrival?.name),
            status: status(bookingStatus: trip.bookingStatus, productStatus: trip.bookingProductStatus),
            rateDetails: details
        )
    }

    func rateDetails(from price: GraphQLMoney?) -> BookingRateDetails? {
        guard let price else { return nil }
        return BookingRateDetails(
            totalPriceAmount: price.amount,
            totalPriceCurrency: price.currency
        )
    }

    /// Wie Check24: Straße, PLZ+Stadt, Land — nur vorhandene Teile, keine Platzhalter.
    func hotelAddress(street: String?, postalCode: String?, city: String?, countryCode: String?) -> String? {
        let streetPart = nonEmpty(street)
        let cityPart: String? = {
            switch (nonEmpty(city), nonEmpty(postalCode)) {
            case let (city?, zip?): return "\(zip) \(city)"
            case let (city?, nil): return city
            case let (nil, zip?): return zip
            default: return nil
            }
        }()
        let countryPart = nonEmpty(countryCode)
        let parts = [streetPart, cityPart, countryPart].compactMap { $0 }
        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: ", ")
    }

    /// Für FlightTimeZoneAssigner / Deep-Links: `"Singapur (SIN)"`.
    func cityWithIata(city: String?, iata: String?) -> String? {
        let cityPart = nonEmpty(city)
        let iataPart = nonEmpty(iata)?.uppercased()
        switch (cityPart, iataPart) {
        case let (city?, iata?):
            return "\(city) (\(iata))"
        case let (city?, nil):
            return city
        case let (nil, iata?):
            return iata
        default:
            return nil
        }
    }

    func roomCategory(from rooms: [GraphQLBookingRoom]?) -> String? {
        guard let rooms else { return nil }
        var seen = Set<String>()
        var ordered: [String] = []
        for room in rooms {
            guard let name = nonEmpty(room.roomDescription) else { continue }
            if seen.insert(name).inserted {
                ordered.append(name)
            }
        }
        guard !ordered.isEmpty else { return nil }
        return ordered.joined(separator: ", ")
    }

    func roomItems(from rooms: [GraphQLBookingRoom]?) -> [BookingRoomItem] {
        guard let rooms else { return [] }
        let items: [BookingRoomItem] = rooms.enumerated().compactMap { idx, room in
            guard let category = nonEmpty(room.roomDescription) else { return nil }
            return BookingRoomItem(
                category: category,
                sortIndex: idx
            )
        }
        return items
    }

    func nonEmpty(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    func boardType(from raw: String?) -> BookingBoardType {
        switch raw?.uppercased() {
        case "BB", "BREAKFAST":
            return .breakfastIncluded
        case "HB":
            return .halfBoard
        case "FB":
            return .fullBoard
        case "RO", "ROOM_ONLY":
            return .roomOnly
        default:
            return .unknown
        }
    }

    /// „14:00-23:59“ / „12:00“ → Minuten seit Mitternacht (erster Uhrzeit-Block).
    func parseClockMinutes(_ raw: String?) -> Int? {
        guard let raw, !raw.isEmpty else { return nil }
        guard let match = raw.range(of: #"\d{1,2}:\d{2}"#, options: .regularExpression) else {
            return nil
        }
        let token = String(raw[match])
        let parts = token.split(separator: ":")
        guard parts.count == 2,
              let hours = Int(parts[0]),
              let minutes = Int(parts[1]),
              (0...23).contains(hours),
              (0...59).contains(minutes) else {
            return nil
        }
        return hours * 60 + minutes
    }

    func status(bookingStatus: String?, productStatus: String?) -> BookingStatus {
        if OpodoTripCancellationGraphQLParser.status(
            bookingStatus: bookingStatus,
            productStatus: productStatus
        ) == .cancelled {
            return .cancelled
        }
        let combined = [bookingStatus, productStatus]
            .compactMap { $0?.uppercased() }
        if combined.contains("CONFIRMED") || combined.contains("CONTRACT") {
            return .confirmed
        }
        return .unknown
    }

    func dateFromEpochMillis(_ raw: Int64?) -> Date? {
        guard let raw else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(raw) / 1000)
    }
}

// MARK: - Codable DTOs

private struct Envelope: Decodable {
    let data: DataContainer?
}

private struct DataContainer: Decodable {
    let getTrips: TripsContainer?
}

private struct TripsContainer: Decodable {
    let trips: [TripWrapper]?
}

private struct TripWrapper: Decodable {
    let trip: GraphQLTrip?
}

private struct GraphQLTrip: Decodable {
    let id: String?
    let bookingStatus: String?
    let bookingProductStatus: String?
    let tdToken: String?
    let price: GraphQLMoney?
    let travellers: [GraphQLTraveller]?
    let itinerary: GraphQLItinerary?
    let accommodationBooking: GraphQLAccommodation?
}

private struct GraphQLMoney: Decodable {
    let amount: Double
    let currency: String
}

private struct GraphQLTraveller: Decodable {
    let travellerType: String?
}

private struct GraphQLItinerary: Decodable {
    let departureDate: Int64?
    let arrivalDate: Int64?
    let origin: GraphQLPlace?
    let destination: GraphQLPlace?
    let legs: [GraphQLLeg]?
}

private struct GraphQLPlace: Decodable {
    let cityName: String?
    let iata: String?
}

private struct GraphQLLeg: Decodable {
    let sections: [GraphQLSection]?
}

private struct GraphQLSection: Decodable {
    let pnr: String?
    let flightCode: String?
    let carrier: GraphQLCarrier?
    let departure: GraphQLAirport?
    let arrival: GraphQLAirport?
}

private struct GraphQLCarrier: Decodable {
    let name: String?
}

private struct GraphQLAirport: Decodable {
    let iata: String?
    let name: String?
}

private struct GraphQLAccommodation: Decodable {
    let id: String?
    let city: String?
    let bookingStatus: String?
    let accommodationName: String?
    let address: String?
    let postalCode: String?
    let countryCode: String?
    let checkInDate: Int64?
    let checkOutDate: Int64?
    let checkIn: String?
    let checkOut: String?
    let boardType: String?
    let numberOfRooms: Int?
    let numberOfAdults: Int?
    let numberOfChildren: Int?
    let bookingRooms: [GraphQLBookingRoom]?
}

private struct GraphQLBookingRoom: Decodable {
    let roomDescription: String?
}
