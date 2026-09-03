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
        guestHintsByBasketId: [String: [BookingGuestHint]],
        guestHintsByBookingURL: [String: [BookingGuestHint]],
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
            let guestHints = guestHintsByBasketId[basketId]
                ?? guestHintsByBookingURL[canonicalExternalUrl]
                ?? []

            let enrichedDetails = bookingDetailsByBasketId[basketId]
                ?? canonicalBooking.identityKey
                    .flatMap { bookingDetailsByBookingKey[$0] }
            let mergedDetails = ParsedBookingDetails.merging(enrichedDetails, with: canonicalBooking.details)
            let rateDetails = mapBasketRateDetails(basket: basket, details: mergedDetails)

            let deadlines = deadlinesParsed.map(\.asDomain)
            let basketConfirmation = basket.items
                .compactMap(\.bookingNumber)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: ", ")
            let times = TemporalFact.pair(
                bookingType: canonicalBooking.type,
                start: canonicalBooking.startAt,
                end: canonicalBooking.endAt
            )

            guard let draft = DraftAssembler.draft(
                from: ProviderBookingFacts(
                    provider: .check24,
                    bookingType: canonicalBooking.type,
                    start: times.start,
                    end: times.end,
                    title: canonicalBooking.title,
                    confirmationCode: basketConfirmation.isEmpty
                        ? canonicalBooking.confirmationCode
                        : basketConfirmation,
                    externalUrl: canonicalExternalUrl,
                    locationFrom: canonicalBooking.locationFrom,
                    locationTo: preferStayLocation(stay?.locationTo, over: canonicalBooking.locationTo),
                    locationFromAddress: canonicalBooking.locationFromAddress,
                    locationToAddress: preferStayLocation(
                        stay?.locationToAddress,
                        over: canonicalBooking.locationToAddress
                    ),
                    statusRaw: canonicalBooking.statusRaw,
                    deadlines: deadlines,
                    rateDetails: rateDetails,
                    hotelCheckInMinutes: stay?.checkInMinutes,
                    hotelCheckOutMinutes: stay?.checkOutMinutes,
                    rawPayloadFingerprint: mergedDetails?.rawDetailsFingerprint,
                    guestHints: guestHints
                )
            ) else {
                continue
            }

            draftByExternalUrl[canonicalExternalUrl] = draft
        }

        return draftByExternalUrl
    }

    func addNonBasketDrafts(
        activity: ParsedActivity,
        bookingUuidToBasketId: [String: String],
        deadlinesByBookingURL: [String: [ParsedCancellationDeadline]],
        hotelStayByBookingURL: [String: HotelCheckInOut],
        guestHintsByBookingURL: [String: [BookingGuestHint]],
        bookingDetailsByBookingKey: [String: ParsedBookingDetails],
        carRentalDetailByBookingKey: [String: ParsedCarRentalDetail] = [:],
        draftByExternalUrl: inout [String: ProviderBookingDraft]
    ) {
        for parsed in activity.bookings {
            if parsed.type == .hotel, let externalUrl = parsed.externalUrl {
                let bookingUuid = String(externalUrl.split(separator: "/").last ?? "")
                if bookingUuidToBasketId[bookingUuid] != nil {
                    continue
                }
            }

            guard parsed.type == .hotel
                || parsed.type == .carRental
                || parsed.type.supportsFlightOffsetAutofill else { continue }

            guard let draft = mapDraft(
                parsed,
                allBookings: activity.bookings,
                deadlinesByBookingURL: deadlinesByBookingURL,
                hotelStayByBookingURL: hotelStayByBookingURL,
                guestHintsByBookingURL: guestHintsByBookingURL,
                bookingDetailsByBookingKey: bookingDetailsByBookingKey,
                carRentalDetail: parsed.identityKey.flatMap { carRentalDetailByBookingKey[$0] }
            ) else { continue }
            guard let key = draft.externalUrl else { continue }
            draftByExternalUrl[key] = draft
        }
    }
}
