import Foundation
import ReisenDomain
import ReisenProviders

extension Check24TravelProvider {
    func makeBasketDrafts(
        basketsByBasketId: [String: HotelBasketParser.ParsedHotelBasket],
        canonicalBookingUuidByBasketId: [String: String],
        parsedBookingByBookingUuid: [String: ParsedBooking],
        deadlinesByBasketId: [String: [ParsedCancellationDeadline]],
        deadlinesByBookingURL: [String: [ParsedCancellationDeadline]],
        hotelStayByBasketId: [String: HotelCheckInOut],
        hotelStayByBookingURL: [String: HotelCheckInOut],
        bookingDetailsByBasketId: [String: ParsedBookingDetails],
        bookingDetailsByBookingKey: [String: ParsedBookingDetails]
    ) -> [String: ProviderBookingDraft] {
        var draftByExternalUrl: [String: ProviderBookingDraft] = [:]

        for (basketId, basket) in basketsByBasketId {
            let canonicalUUID = canonicalBookingUuidByBasketId[basketId]
                ?? basket.items.map(\.bookingUuid).sorted().first

            guard let canonicalUUID,
                  let canonicalBooking = parsedBookingByBookingUuid[canonicalUUID],
                  let canonicalExternalUrl = canonicalBooking.externalUrl else {
                continue
            }

            let deadlinesParsed = deadlinesByBasketId[basketId]
                ?? deadlinesByBookingURL[canonicalExternalUrl]
                ?? []
            let stay = hotelStayByBasketId[basketId] ?? hotelStayByBookingURL[canonicalExternalUrl]

            let enrichedDetails = bookingDetailsByBasketId[basketId]
                ?? identityKey(for: canonicalBooking)
                    .flatMap { bookingDetailsByBookingKey[$0] }
            let mergedDetails = mergeBookingDetails(primary: enrichedDetails, secondary: canonicalBooking.details)
            let rateDetails = mapBasketRateDetails(basket: basket, details: mergedDetails)

            let deadlines = deadlinesParsed.map(mapDeadline)
            let basketConfirmation = basket.items
                .compactMap(\.bookingNumber)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: ", ")

            let draft = ProviderBookingDraft(
                provider: .check24,
                bookingType: canonicalBooking.type,
                title: canonicalBooking.title,
                confirmationCode: basketConfirmation.isEmpty ? canonicalBooking.confirmationCode : basketConfirmation,
                externalUrl: canonicalExternalUrl,
                startAt: canonicalBooking.startAt,
                endAt: canonicalBooking.endAt,
                locationFrom: canonicalBooking.locationFrom,
                locationTo: canonicalBooking.locationTo,
                locationFromAddress: canonicalBooking.locationFromAddress,
                locationToAddress: canonicalBooking.locationToAddress,
                status: canonicalBooking.status,
                deadlines: deadlines,
                rateDetails: rateDetails,
                hotelOffsetSeconds: deadlines.compactMap(\.hotelOffsetSeconds).first,
                hotelCheckInMinutes: stay?.checkInMinutes,
                hotelCheckOutMinutes: stay?.checkOutMinutes,
                rawPayloadFingerprint: mergedDetails?.rawDetailsFingerprint
            )

            draftByExternalUrl[canonicalExternalUrl] = draft
        }

        return draftByExternalUrl
    }

    func addNonBasketDrafts(
        activity: ParsedActivity,
        bookingUuidToBasketId: [String: String],
        deadlinesByBookingURL: [String: [ParsedCancellationDeadline]],
        hotelStayByBookingURL: [String: HotelCheckInOut],
        bookingDetailsByBookingKey: [String: ParsedBookingDetails],
        draftByExternalUrl: inout [String: ProviderBookingDraft]
    ) {
        for parsed in activity.bookings {
            if parsed.type == .hotel, let externalUrl = parsed.externalUrl {
                let bookingUuid = String(externalUrl.split(separator: "/").last ?? "")
                if bookingUuidToBasketId[bookingUuid] != nil {
                    continue
                }
            }

            guard parsed.type == .flight || parsed.type == .ferry || parsed.type == .hotel else { continue }

            let draft = mapDraft(
                parsed,
                allBookings: activity.bookings,
                deadlinesByBookingURL: deadlinesByBookingURL,
                hotelStayByBookingURL: hotelStayByBookingURL,
                bookingDetailsByBookingKey: bookingDetailsByBookingKey
            )
            guard let key = draft.externalUrl else { continue }
            draftByExternalUrl[key] = draft
        }
    }
}
