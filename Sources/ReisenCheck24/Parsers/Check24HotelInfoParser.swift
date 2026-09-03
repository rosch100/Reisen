import Foundation
import ReisenDomain

/// Hotel-Ort, -Adresse und Check-in/-out aus eingebettetem `hotelInfo` auf der Buchungsdetailseite.
public enum Check24HotelInfoParser {
    static let hotelInfoKey = "\"hotelInfo\""
    static let cityStreetKey = "\"cityStreet\""
    static let checkInCheckOutKey = "\"checkInCheckOut\""

    /// Soft-Wait: `hotelInfo` mit Straße **oder** Check-in/out-Zeiten (Parse akzeptiert beides).
    public static let domAddressPayloadCondition = """
        document.documentElement.outerHTML.includes('\(hotelInfoKey)') &&
        (document.documentElement.outerHTML.includes('\(cityStreetKey)') ||
         document.documentElement.outerHTML.includes('\(checkInCheckOutKey)'))
        """

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
        let checkInMinutes = ClockTime.minutes(fromHHMM: dto.checkInCheckOut?.checkInFrom)
        let checkOutMinutes = ClockTime.minutes(fromHHMM: dto.checkInCheckOut?.checkOutTo)
        guard locationTo != nil
            || locationToAddress != nil
            || checkInMinutes != nil
            || checkOutMinutes != nil else {
            return nil
        }
        return ParsedHotelInfo(
            locationTo: locationTo,
            locationToAddress: locationToAddress,
            checkInMinutes: checkInMinutes,
            checkOutMinutes: checkOutMinutes
        )
    }
}

struct Check24HotelInfoDTO: Decodable {
    let cityStreet: String?
    let zip: String?
    let cityName: String?
    let countryName: String?
    let fullCountryNameGerman: String?
    let checkInCheckOut: CheckInCheckOut?

    struct CheckInCheckOut: Decodable {
        let checkInFrom: String?
        let checkOutTo: String?
    }
}

public struct ParsedHotelInfo: Equatable, Sendable {
    public let locationTo: String?
    public let locationToAddress: String?
    public let checkInMinutes: Int?
    public let checkOutMinutes: Int?

    public init(
        locationTo: String?,
        locationToAddress: String?,
        checkInMinutes: Int? = nil,
        checkOutMinutes: Int? = nil
    ) {
        self.locationTo = locationTo
        self.locationToAddress = locationToAddress
        self.checkInMinutes = checkInMinutes
        self.checkOutMinutes = checkOutMinutes
    }
}
