import Foundation

/// Verwirft Extractions ohne Typ oder Startzeitpunkt und macht die restlichen zu typisierten Drafts.
public enum PasteImportFilter {
    public static func apply(_ extractions: [PasteImportExtraction]) -> [PasteImportDraft] {
        extractions.compactMap(draft)
    }

    private static func draft(from extraction: PasteImportExtraction) -> PasteImportDraft? {
        guard let bookingType = extraction.bookingType, let startAt = extraction.startAt else {
            return nil
        }
        return PasteImportDraft(
            bookingType: bookingType,
            startAt: startAt,
            endAt: extraction.endAt ?? startAt,
            endAtIsPlaceholder: extraction.endAt == nil,
            title: NonEmpty.string(extraction.title),
            confirmationCode: NonEmpty.string(extraction.confirmationCode),
            externalUrl: NonEmpty.string(extraction.externalUrl),
            locationFrom: NonEmpty.string(extraction.locationFrom),
            locationTo: NonEmpty.string(extraction.locationTo),
            locationFromAddress: NonEmpty.string(extraction.locationFromAddress),
            locationToAddress: NonEmpty.string(extraction.locationToAddress),
            operatorName: NonEmpty.string(extraction.operatorName),
            status: extraction.status ?? .unknown,
            hotelCheckInMinutes: extraction.hotelCheckInMinutes,
            hotelCheckOutMinutes: extraction.hotelCheckOutMinutes,
            hotelOffsetSeconds: extraction.hotelOffsetSeconds,
            flightDepartureOffsetSeconds: extraction.flightDepartureOffsetSeconds,
            flightArrivalOffsetSeconds: extraction.flightArrivalOffsetSeconds,
            passengers: extraction.passengers,
            guestHints: extraction.guestHints,
            rateDetails: extraction.rateDetails,
            deadlines: extraction.deadlines
        )
    }
}
