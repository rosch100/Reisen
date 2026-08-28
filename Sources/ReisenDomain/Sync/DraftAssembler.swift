import Foundation

public enum DraftAssembler {
    public enum Error: Swift.Error, Equatable, Sendable, LocalizedError {
        case missingDateWindow
        case droppedFromCatalog

        public var errorDescription: String? {
            switch self {
            case .missingDateWindow:
                return "Buchung ohne gültiges Start-/Endedatum."
            case .droppedFromCatalog:
                return "Buchung ist storniert oder abgeschlossen."
            }
        }
    }

    public static func requireDraft(from facts: ProviderBookingFacts) throws -> ProviderBookingDraft {
        guard let draft = draft(from: facts) else {
            throw CatalogListing.shouldDrop(facts.statusRaw)
                ? Error.droppedFromCatalog
                : Error.missingDateWindow
        }
        return draft
    }

    public static func draft(from facts: ProviderBookingFacts) -> ProviderBookingDraft? {
        guard !CatalogListing.shouldDrop(facts.statusRaw) else {
            return nil
        }
        guard let window = dateWindow(from: facts) else {
            return nil
        }
        let flights = flightOffsets(from: facts, window: window)

        return ProviderBookingDraft(
            provider: facts.provider,
            bookingType: facts.bookingType,
            title: facts.title,
            confirmationCode: facts.confirmationCode,
            externalUrl: facts.externalUrl,
            startAt: window.startAt,
            endAt: window.endAt,
            locationFrom: facts.locationFrom,
            locationTo: facts.locationTo,
            locationFromAddress: facts.locationFromAddress,
            locationToAddress: facts.locationToAddress,
            operatorName: facts.operatorName,
            isAllDay: facts.isAllDay,
            status: BookingStatus.parse(facts.statusRaw),
            deadlines: facts.deadlines,
            rateDetails: facts.rateDetails,
            hotelOffsetSeconds: stayOffsetSeconds(from: facts, window: window),
            hotelCheckInMinutes: facts.hotelCheckInMinutes,
            hotelCheckOutMinutes: facts.hotelCheckOutMinutes,
            flightDepartureOffsetSeconds: flights.departure,
            flightArrivalOffsetSeconds: flights.arrival,
            rawPayloadFingerprint: facts.rawPayloadFingerprint,
            passengers: facts.passengers,
            guestHints: facts.guestHints
        )
    }

    public static func enrichment(from facts: ProviderBookingFacts) -> ProviderBookingEnrichment {
        let window = dateWindow(from: facts)
        let flights = flightOffsets(from: facts, window: window)
        let status = BookingStatus.parse(facts.statusRaw)
        let cancelled = status == .cancelled
        return ProviderBookingEnrichment(
            deadlines: cancelled ? [] : facts.deadlines,
            rateDetails: facts.rateDetails,
            passengers: facts.passengers.isEmpty ? nil : facts.passengers,
            guestHints: facts.guestHints.isEmpty ? nil : facts.guestHints,
            hotelOffsetSeconds: cancelled ? nil : stayOffsetSeconds(from: facts, window: window),
            hotelCheckInMinutes: facts.hotelCheckInMinutes,
            hotelCheckOutMinutes: facts.hotelCheckOutMinutes,
            flightDepartureOffsetSeconds: flights.departure,
            flightArrivalOffsetSeconds: flights.arrival,
            status: status == .unknown ? nil : status,
            title: facts.title,
            locationFrom: facts.locationFrom,
            locationTo: facts.locationTo,
            locationFromAddress: facts.locationFromAddress,
            locationToAddress: facts.locationToAddress,
            operatorName: facts.operatorName,
            isAllDay: facts.isAllDay
        )
    }

    private static func dateWindow(from facts: ProviderBookingFacts) -> BookingDateWindow? {
        guard let start = facts.start, let end = facts.end else { return nil }
        return BookingDateWindow.resolve(type: facts.bookingType, start: start, end: end)
    }

    private static func flightOffsets(
        from facts: ProviderBookingFacts,
        window: BookingDateWindow?
    ) -> (departure: Int?, arrival: Int?) {
        (
            facts.flightDepartureOffsetSeconds ?? window?.flightDepartureOffsetSeconds,
            facts.flightArrivalOffsetSeconds ?? window?.flightArrivalOffsetSeconds
        )
    }

    private static func stayOffsetSeconds(
        from facts: ProviderBookingFacts,
        window: BookingDateWindow?
    ) -> Int? {
        switch facts.bookingType {
        case .hotel:
            return facts.hotelOffsetSeconds
                ?? window?.hotelOffsetSeconds
                ?? facts.deadlines.firstStayOffsetSeconds
        case .carRental:
            // Pickup-/Storno-Ortszeit; Feld `hotelOffsetSeconds`. `BookingDateWindow` liefert hier keinen Offset.
            return facts.hotelOffsetSeconds
                ?? facts.deadlines.firstStayOffsetSeconds
        case .flight, .ferry, .activity, .other:
            return nil
        }
    }
}
