import Foundation
import ReisenDomain
import WebKit

/// Parses Opodo GraphQL responses for flight `travellers` and `baggageInfo`.
public enum OpodoFlightPassengersGraphQL {
    private static let supportAreaGraphQLURL = URL(string: "https://www.opodo.de/support-area-bff/service/graphql")!

    public static func getTripByTokenSupportAreaRequestBody(token: String) throws -> Data {
        let payload: [String: Any] = [
            "query": """
            query getTripByTokenSupportArea($token: String!) {
              getTripByToken(token: $token) {
                trip {
                  travellers {
                    travellerType
                    name
                    title
                    firstLastName
                    secondLastName
                    birthDate
                  }
                }
              }
            }
            """,
            "operationName": "getTripByTokenSupportArea",
            "variables": [
                "token": token,
            ],
        ]
        return try JSONSerialization.data(withJSONObject: payload, options: [])
    }

    public static func baggageInfoRequestBody(tripDetailsToken: String) throws -> Data {
        let payload: [String: Any] = [
            "query": """
            query baggageInfo($request: BookingBaggageInfoRequest!) {
              baggageInfo(request: $request) {
                travellers {
                  numPassenger
                  sections {
                    id
                    airlineCode
                    baggageList {
                      type
                      numPieces
                      weight
                      dimensions { length width height }
                    }
                  }
                }
              }
            }
            """,
            "operationName": "baggageInfo",
            "variables": [
                "request": [
                    "tripDetailsToken": tripDetailsToken,
                ],
            ],
        ]
        return try JSONSerialization.data(withJSONObject: payload, options: [])
    }

    public static func fetchPassengersAndBaggage(
        token: String,
        tripDetailsToken: String,
        using webView: WKWebView
    ) async throws -> [BookingPassenger] {
        let travellersBody = try getTripByTokenSupportAreaRequestBody(token: token)
        let travellersJSON = try await webView.fetchAuthenticatedText(
            url: supportAreaGraphQLURL,
            method: "POST",
            accept: "application/json",
            referer: "https://www.opodo.de/travel/secure/",
            contentType: "application/json",
            body: travellersBody
        )

        let passengers = try parseTravellers(from: travellersJSON)

        let baggageBody = try baggageInfoRequestBody(tripDetailsToken: tripDetailsToken)
        let baggageJSON = try await webView.fetchAuthenticatedText(
            url: supportAreaGraphQLURL,
            method: "POST",
            accept: "application/json",
            referer: "https://www.opodo.de/travel/secure/",
            contentType: "application/json",
            body: baggageBody
        )
        return try joinBaggage(from: passengers, baggageJSON: baggageJSON)
    }

    /// Test- & Debug-Entry: joint support-area `travellers` mit `baggageInfo` zu strukturierten Passagieren.
    public static func parsePassengersAndBaggage(travellersJSON: String, baggageJSON: String) throws -> [BookingPassenger] {
        let passengers = try parseTravellers(from: travellersJSON)
        return try joinBaggage(from: passengers, baggageJSON: baggageJSON)
    }

    private static func parseTravellers(from json: String) throws -> [BookingPassenger] {
        let envelope = try decodeSupportAreaEnvelope(json: json)
        let dtos = envelope.data.getTripByToken.trip.travellers
        guard !dtos.isEmpty else {
            throw OpodoFlightPassengersError.noTravellers
        }

        // SupportArea doesn't provide `numPassenger`, so we derive passengerNumber by array index.
        return dtos.enumerated().map { idx, dto in
            BookingPassenger(
                passengerNumber: idx + 1,
                travellerType: TravellerType(rawValue: (dto.travellerType ?? "").uppercased().lowercased())
                    ?? .unknown,
                title: dto.title,
                givenName: dto.name,
                familyName: dto.firstLastName,
                secondFamilyName: dto.secondLastName,
                birthDate: parseISODateTime(dto.birthDate),
                baggageAllowances: []
            )
        }
    }

    private static func joinBaggage(from passengers: [BookingPassenger], baggageJSON: String) throws -> [BookingPassenger] {
        let envelope = try decodeBaggageEnvelope(json: baggageJSON)
        var mutable = passengers

        func passengerIndex(forNumPassenger num: Int) -> Int? {
            // passengerNumber is 1..n derived by index in parseTravellers.
            let i = num - 1
            guard mutable.indices.contains(i) else { return nil }
            return i
        }

        for t in envelope.data.baggageInfo.travellers ?? [] {
            guard let idx = passengerIndex(forNumPassenger: t.numPassenger ?? -1) else {
                continue
            }
            var allowance: [BaggageAllowance] = []
            for section in t.sections ?? [] {
                for bag in section.baggageList ?? [] {
                    let rawType = bag.type ?? ""
                    let baggageType: BaggageType
                    switch rawType.uppercased() {
                    case "CHECKED_BAG": baggageType = .checkedBag
                    case "CABIN_BAG": baggageType = .cabinBag
                    case "PERSONAL_ITEM": baggageType = .personalItem
                    default: baggageType = .unknown
                    }

                    let weightKg = (bag.weight ?? -1) >= 0 ? bag.weight : nil

                    allowance.append(
                        BaggageAllowance(
                            passengerID: mutable[idx].id,
                            type: baggageType,
                            pieceCount: bag.numPieces,
                            weightKg: weightKg,
                            sectionID: section.id,
                            airlineCode: section.airlineCode
                        )
                    )
                }
            }
            mutable[idx].baggageAllowances = allowance
        }

        return mutable
    }

    private static func parseISODateTime(_ raw: String?) -> Date? {
        guard let raw, !raw.isEmpty else { return nil }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: raw) { return d }
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: raw)
    }

    private static func decodeSupportAreaEnvelope(json: String) throws -> SupportAreaEnvelope {
        guard let data = json.data(using: .utf8) else { throw OpodoFlightPassengersError.invalidJSON }
        do {
            return try JSONDecoder().decode(SupportAreaEnvelope.self, from: data)
        } catch {
            throw OpodoFlightPassengersError.invalidJSON
        }
    }

    private static func decodeBaggageEnvelope(json: String) throws -> BaggageEnvelope {
        guard let data = json.data(using: .utf8) else { throw OpodoFlightPassengersError.invalidJSON }
        do {
            return try JSONDecoder().decode(BaggageEnvelope.self, from: data)
        } catch {
            throw OpodoFlightPassengersError.invalidJSON
        }
    }
}

public enum OpodoFlightPassengersError: LocalizedError, Sendable {
    case invalidJSON
    case noTravellers

    public var errorDescription: String? {
        switch self {
        case .invalidJSON: return "Opodo Flug-Passagiere/Gepäck konnte nicht gelesen werden."
        case .noTravellers: return "Opodo liefert keine Flug-Passagiere."
        }
    }
}

private struct SupportAreaEnvelope: Decodable {
    struct Root: Decodable {
        let getTripByToken: TripWrapper
    }
    let data: Root

    struct TripWrapper: Decodable {
        let trip: TripDTO
    }

    struct TripDTO: Decodable {
        let travellers: [TravellerDTO]
    }

    struct TravellerDTO: Decodable {
        let travellerType: String?
        let name: String?
        let title: String?
        let firstLastName: String?
        let secondLastName: String?
        let birthDate: String?
    }
}

private struct BaggageEnvelope: Decodable {
    struct Root: Decodable {
        let baggageInfo: BaggageInfoDTO
    }

    let data: Root

    struct BaggageInfoDTO: Decodable {
        let travellers: [BaggageTravellerDTO]?
    }

    struct BaggageTravellerDTO: Decodable {
        let numPassenger: Int?
        let sections: [BaggageSectionDTO]?
    }

    struct BaggageSectionDTO: Decodable {
        let id: String?
        let airlineCode: String?
        let baggageList: [BaggageListDTO]?
    }

    struct BaggageListDTO: Decodable {
        let type: String?
        let numPieces: Int?
        let weight: Double?
    }
}

