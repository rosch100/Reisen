import Foundation

extension ProviderBookingDraft {
    public var enrichmentRef: ProviderBookingRef? {
        guard let externalUrl else { return nil }
        return ProviderBookingRef(
            externalUrl: externalUrl,
            bookingType: bookingType,
            hotelOffsetSeconds: hotelOffsetSeconds
        )
    }

    public mutating func apply(_ enrichment: ProviderBookingEnrichment) {
        status = enrichment.status ?? status
        assignNonEmpty(enrichment.title, to: \.title)
        assignNonEmpty(enrichment.locationFrom, to: \.locationFrom)
        assignNonEmpty(enrichment.locationTo, to: \.locationTo)
        assignNonEmpty(enrichment.locationFromAddress, to: \.locationFromAddress)
        assignNonEmpty(enrichment.locationToAddress, to: \.locationToAddress)

        applyDeadlinesAndStayOffset(from: enrichment)

        passengers = enrichment.passengers ?? passengers
        guestHints = enrichment.guestHints ?? guestHints
        rateDetails = BookingRateDetails.merging(existing: rateDetails, incoming: enrichment.rateDetails)
        hotelCheckInMinutes = enrichment.hotelCheckInMinutes ?? hotelCheckInMinutes
        hotelCheckOutMinutes = enrichment.hotelCheckOutMinutes ?? hotelCheckOutMinutes
        flightDepartureOffsetSeconds = enrichment.flightDepartureOffsetSeconds ?? flightDepartureOffsetSeconds
        flightArrivalOffsetSeconds = enrichment.flightArrivalOffsetSeconds ?? flightArrivalOffsetSeconds
        operatorName = enrichment.operatorName ?? operatorName
        isAllDay = enrichment.isAllDay ?? isAllDay
    }

    /// Storno ersetzt Katalog-Fristen und Stay-Offset auch dann, wenn das Enrichment leer bzw. `nil` ist.
    /// Sonst gilt: leere Fristen und fehlender Offset überschreiben den Katalog nicht.
    private mutating func applyDeadlinesAndStayOffset(from enrichment: ProviderBookingEnrichment) {
        if status == .cancelled {
            deadlines = enrichment.deadlines
            hotelOffsetSeconds = enrichment.hotelOffsetSeconds
            return
        }
        if !enrichment.deadlines.isEmpty {
            deadlines = enrichment.deadlines
        }
        hotelOffsetSeconds = enrichment.hotelOffsetSeconds ?? hotelOffsetSeconds
    }

    private mutating func assignNonEmpty(_ value: String?, to keyPath: WritableKeyPath<Self, String?>) {
        guard let value, !value.isEmpty else { return }
        self[keyPath: keyPath] = value
    }
}
