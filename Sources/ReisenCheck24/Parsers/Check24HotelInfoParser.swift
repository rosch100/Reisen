import Foundation
import ReisenDomain

/// Hotel-Ort und -Adresse aus eingebettetem `hotelInfo` auf der Buchungsdetailseite.
public enum Check24HotelInfoParser {
    static let hotelInfoKey = "\"hotelInfo\""

    public static func parse(from html: String) -> ParsedHotelInfo? {
        guard let json = HotelBasketJSONScan.extractTopLevelJSONObject(
            from: html,
            after: hotelInfoKey
        ) else {
            return nil
        }
        guard let data = json.data(using: .utf8) else { return nil }
        do {
            let dto = try JSONDecoder().decode(Check24HotelInfoDTO.self, from: data)
            return place(from: dto)
        } catch {
            return nil
        }
    }

    private static func place(from dto: Check24HotelInfoDTO) -> ParsedHotelInfo? {
        let locationTo = NonEmpty.string(dto.cityName)
        let locationToAddress = PostalAddress.lines(
            street: dto.cityStreet,
            postalCode: dto.zip,
            city: dto.cityName,
            country: NonEmpty.first(dto.fullCountryNameGerman, dto.countryName)
        )
        guard locationTo != nil || locationToAddress != nil else { return nil }
        return ParsedHotelInfo(locationTo: locationTo, locationToAddress: locationToAddress)
    }
}

struct Check24HotelInfoDTO: Decodable {
    let cityStreet: String?
    let zip: String?
    let cityName: String?
    let countryName: String?
    let fullCountryNameGerman: String?
}

public struct ParsedHotelInfo: Equatable, Sendable {
    public let locationTo: String?
    public let locationToAddress: String?
}
