import Foundation
import ReisenDomain
import ReisenProviders

/// Parst FLOYT `useraccount/v1/web/bookings/{id}` → Enrichment.
public enum BilligerMietwagenBookingDetailParser {
    public static func parse(
        from jsonText: String,
        catalogStartAt: Date? = nil,
        hotelOffsetSeconds: Int? = nil
    ) throws -> ProviderBookingEnrichment {
        let detail = try BilligerMietwagenJSON.decode(WebDetail.self, from: jsonText)
        let pickUp = detail.rental?.pickUp
        let dropOff = detail.rental?.dropOff
        let freeCancellation = detail.offer?.freeCancellation == true
        let cancelUntil = detail.reservation?.cancelUntil

        return DraftAssembler.enrichment(
            from: ProviderBookingFacts(
                provider: .billigerMietwagen,
                bookingType: .carRental,
                // Zeiten: Katalog-SSOT (Detail-`datetime` oft ohne Offset).
                title: NonEmpty.string(detail.offer?.model),
                confirmationCode: NonEmpty.string(detail.reservation?.id),
                locationFrom: NonEmpty.string(pickUp?.address?.city),
                locationTo: NonEmpty.string(dropOff?.address?.city),
                locationFromAddress: formatAddress(pickUp?.address),
                locationToAddress: formatAddress(dropOff?.address),
                operatorName: NonEmpty.first(detail.offer?.supplier, detail.offer?.provider),
                statusRaw: NonEmpty.string(detail.reservation?.status),
                deadlines: cancellationDeadlines(
                    cancelUntil: cancelUntil,
                    freeCancellation: freeCancellation,
                    freeCancellationHours: detail.offer?.freeCancellationHours,
                    pickUpDateTime: pickUp?.datetime,
                    catalogStartAt: catalogStartAt,
                    hotelOffsetSeconds: hotelOffsetSeconds
                ),
                rateDetails: BookingRateDetails(
                    totalPriceAmount: detail.offer?.price,
                    totalPriceCurrency: detail.offer?.currency,
                    roomCategory: NonEmpty.first(detail.offer?.transmission, detail.offer?.carClassName)
                ),
                hotelOffsetSeconds: hotelOffsetSeconds,
                passengers: passengers(from: detail.driver),
                guestHints: guestHints(from: detail, cancelUntil: cancelUntil)
            )
        )
    }

    // MARK: - Mapping helpers

    private static func passengers(from driver: Driver?) -> [BookingPassenger] {
        guard let name = NonEmpty.string(driver?.name) else { return [] }
        return [
            BookingPassenger(
                passengerNumber: 1,
                travellerType: .adult,
                givenName: name
            )
        ]
    }

    private static func guestHints(from detail: WebDetail, cancelUntil: String?) -> [BookingGuestHint] {
        var hints: [BookingGuestHint] = []
        // Stunden-Hint nur ohne Portal-`cancelUntil` (gleiche Policy wie Deadlines: Portal-Frist hat Vorrang).
        if !hasPortalCancelUntil(cancelUntil),
           detail.offer?.freeCancellation == true,
           let hours = detail.offer?.freeCancellationHours
        {
            hints.append(
                hint(
                    title: "Stornierung",
                    detail: "Kostenlose Stornierung bis \(hours) Stunden vor Abholung",
                    sourceKey: "bm:freeCancellationHours:\(hours)"
                )
            )
        }
        if let fuel = NonEmpty.string(detail.offer?.fuelPolicy) {
            hints.append(hint(title: "Tankregelung", detail: fuel, sourceKey: "bm:fuelPolicy:\(fuel)"))
        }
        if let voucherURL = NonEmpty.string(detail.files?.voucher?.url),
           isAllowedVoucherURL(voucherURL)
        {
            hints.append(hint(title: "Voucher", detail: voucherURL, sourceKey: "bm:voucher:\(voucherURL)"))
        }
        return hints
    }

    /// `true`, wenn das Portal eine absolute Stornofrist liefert (Deadlines + Hint-Policy).
    private static func hasPortalCancelUntil(_ raw: String?) -> Bool {
        NonEmpty.string(raw) != nil
    }

    private static func hint(title: String, detail: String, sourceKey: String) -> BookingGuestHint {
        BookingGuestHint(
            title: title,
            detail: detail,
            sourceKey: sourceKey,
            providerRaw: ProviderID.billigerMietwagen.rawValue
        )
    }

    private static func isAllowedVoucherURL(_ raw: String) -> Bool {
        guard let url = URL(string: raw), let host = url.host else { return false }
        return BilligerMietwagenAuthConstants.isFloytAPIHost(host)
            || BilligerMietwagenAuthConstants.isPortalHost(host)
    }

    /// FLOYT legt oft die komplette Display-Adresse in `street` (inkl. Ort/Land/PLZ)
    /// und liefert `city`/`country` zusätzlich — ohne Dedup entsteht `, …, Berlin, Berlin, DE`.
    private static func formatAddress(_ address: StationAddress?) -> String? {
        guard let address else { return nil }
        return BilligerMietwagenStationAddressFormat.lines(
            street: address.street,
            postalCode: address.postalCode,
            city: address.city,
            country: address.country
        )
    }
}

// MARK: - DTOs (fileprivate — kein Domain-`PostalAddress`-Clash)

private struct WebDetail: Decodable {
    let reservation: Reservation?
    let offer: Offer?
    let rental: Rental?
    let driver: Driver?
    let files: Files?
}

private struct Driver: Decodable {
    let name: String?
}

private struct Files: Decodable {
    let voucher: VoucherFile?
}

private struct VoucherFile: Decodable {
    let url: String?
}

private struct Reservation: Decodable {
    let id: String?
    let status: String?
    let cancelUntil: String?

    enum CodingKeys: String, CodingKey {
        case id, status
        case cancelUntil
        case cancelUntilSnake = "cancel_until"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id)
        status = try container.decodeIfPresent(String.self, forKey: .status)
        cancelUntil = try container.decodeString(preferring: .cancelUntil, or: .cancelUntilSnake)
    }
}

private struct Offer: Decodable {
    let model: String?
    let carClassName: String?
    let transmission: String?
    let provider: String?
    let supplier: String?
    let fuelPolicy: String?
    let freeCancellation: Bool?
    let freeCancellationHours: Int?
    let currency: String?
    let price: Double?

    enum CodingKeys: String, CodingKey {
        case model, transmission, provider, supplier, currency, price
        case carClassName = "car_class_name"
        case fuelPolicy = "fuel_policy"
        case freeCancellation = "free_cancellation"
        case freeCancellationHours = "free_cancellation_hours"
    }
}

private struct Rental: Decodable {
    let pickUp: Station?
    let dropOff: Station?
}

private struct Station: Decodable {
    let address: StationAddress?
    let datetime: String?
}

private struct StationAddress: Decodable {
    let street: String?
    let postalCode: String?
    let city: String?
    let country: String?

    enum CodingKeys: String, CodingKey {
        case street, city, country
        case postalCode = "postalCode"
        case postalCodeSnake = "postal_code"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        street = try container.decodeIfPresent(String.self, forKey: .street)
        city = try container.decodeIfPresent(String.self, forKey: .city)
        country = try container.decodeIfPresent(String.self, forKey: .country)
        postalCode = try container.decodeString(preferring: .postalCode, or: .postalCodeSnake)
    }
}

private extension KeyedDecodingContainer {
    func decodeString(preferring preferred: Key, or fallback: Key) throws -> String? {
        try decodeIfPresent(String.self, forKey: preferred)
            ?? decodeIfPresent(String.self, forKey: fallback)
    }
}
