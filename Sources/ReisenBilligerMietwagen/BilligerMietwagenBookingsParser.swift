import Foundation
import ReisenDomain

/// Eine Seite FLOYT `useraccount/v1/bookings` inkl. Pagination-Hinweis.
public struct BilligerMietwagenBookingsPage: Sendable {
    public let bookings: [ProviderBookingDraft]
    /// Nächste `page`-Query, wenn `_pointers` weitere Seiten signalisiert.
    public let nextPage: Int?

    public init(bookings: [ProviderBookingDraft], nextPage: Int?) {
        self.bookings = bookings
        self.nextPage = nextPage
    }
}

/// Parst FLOYT `useraccount/v1/bookings` → Katalog-Drafts.
public enum BilligerMietwagenBookingsParser {
    public static func parse(from jsonText: String) throws -> ProviderCatalog {
        let page = try parsePage(from: jsonText, fetchedPage: 0)
        return ProviderCatalog(bookings: page.bookings)
    }

    public static func parsePage(from jsonText: String, fetchedPage: Int) throws -> BilligerMietwagenBookingsPage {
        let payload = try BilligerMietwagenJSON.decode(BookingsPayload.self, from: jsonText)
        return BilligerMietwagenBookingsPage(
            bookings: (payload.items ?? []).compactMap(mapItem),
            nextPage: payload.pointers?.nextPageIndex(after: fetchedPage)
        )
    }

    private static let listStatusError = "error"
    private static let bookingTypeCarRental = "car_rental"

    private static func mapItem(_ item: BookingListItem) -> ProviderBookingDraft? {
        let statusRaw = NonEmpty.string(item.status)
        if statusRaw?.lowercased() == listStatusError { return nil }
        guard item.type == bookingTypeCarRental else { return nil }
        guard let id = NonEmpty.string(item.id),
              let startRaw = NonEmpty.string(item.pickUp?.date),
              let endRaw = NonEmpty.string(item.dropOff?.date),
              let startAt = ISODateTime.parseInstant(startRaw),
              let endAt = ISODateTime.parseInstant(endRaw)
        else {
            return nil
        }

        let operatorName = NonEmpty.first(item.supplier?.name, item.provider?.name)
        let fromCity = NonEmpty.string(item.pickUp?.city)
        let toCity = NonEmpty.string(item.dropOff?.city)
        let times = TemporalFact.pair(bookingType: .carRental, start: startAt, end: endAt)
        return DraftAssembler.draft(
            from: ProviderBookingFacts(
                provider: .billigerMietwagen,
                bookingType: .carRental,
                start: times.start,
                end: times.end,
                title: PlaceLabel.route(from: fromCity, to: toCity) ?? operatorName,
                confirmationCode: NonEmpty.string(item.reservationId),
                externalUrl: BilligerMietwagenWebConstants.bookingPageURL(id: id),
                cancellationUrl: BilligerMietwagenWebConstants.cancellationPageURL,
                locationFrom: fromCity,
                locationTo: toCity,
                operatorName: operatorName,
                statusRaw: statusRaw,
                rateDetails: rateDetails(
                    total: item.price?.total,
                    vehicleCategory: NonEmpty.string(item.vehicle?.carClass)
                ),
                hotelOffsetSeconds: ISODateTime.offsetSeconds(from: startRaw),
                rawPayloadFingerprint: id
            )
        )
    }

    private static func rateDetails(total: Money?, vehicleCategory: String?) -> BookingRateDetails? {
        guard let total else {
            return vehicleCategory.map { BookingRateDetails(roomCategory: $0) }
        }
        return BookingRateDetails(
            totalPriceAmount: total.amount,
            totalPriceCurrency: total.currency,
            roomCategory: vehicleCategory
        )
    }
}

// MARK: - DTOs

private struct BookingsPayload: Decodable {
    let items: [BookingListItem]?
    let pointers: BookingsPointers?

    enum CodingKeys: String, CodingKey {
        case items
        case pointers = "_pointers"
    }
}

private struct BookingsPointers: Decodable {
    let selfPage: String?
    let last: String?
    let next: String?

    enum CodingKeys: String, CodingKey {
        case last, next
        case selfPage = "self"
    }

    /// Nächste Seite laut `next`, sonst `self+1` solange `self < last`.
    func nextPageIndex(after fetchedPage: Int) -> Int? {
        if let next, let page = Int(next), page > fetchedPage {
            return page
        }
        let selfIndex = Int(selfPage ?? "") ?? fetchedPage
        guard let lastIndex = Int(last ?? ""), selfIndex < lastIndex else {
            return nil
        }
        let candidate = selfIndex + 1
        return candidate > fetchedPage ? candidate : nil
    }
}

private struct BookingListItem: Decodable {
    let id: String?
    let type: String?
    let status: String?
    let reservationId: String?
    let pickUp: PlaceTime?
    let dropOff: PlaceTime?
    let provider: NamedParty?
    let supplier: NamedParty?
    let price: PriceEnvelope?
    let vehicle: VehicleSummary?

    enum CodingKeys: String, CodingKey {
        case id, type, status, provider, supplier, price, vehicle
        case reservationId = "reservation_id"
        case pickUp = "pick_up"
        case dropOff = "drop_off"
    }
}

private struct PlaceTime: Decodable {
    let city: String?
    let date: String?
}

private struct NamedParty: Decodable {
    let name: String?
}

private struct PriceEnvelope: Decodable {
    let total: Money?
}

private struct Money: Decodable {
    let amount: Double?
    let currency: String?
}

private struct VehicleSummary: Decodable {
    let carClass: String?

    enum CodingKeys: String, CodingKey {
        case carClass = "car_class"
    }
}
