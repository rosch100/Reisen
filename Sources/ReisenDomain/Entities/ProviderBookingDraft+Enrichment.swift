import Foundation

extension ProviderBookingDraft {
    public func needsDeadlineEnrichment(requiresDeadlines: Bool) -> Bool {
        requiresDeadlines && deadlines.isEmpty
    }

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

        if !enrichment.deadlines.isEmpty {
            deadlines = enrichment.deadlines
        }

        passengers = enrichment.passengers ?? passengers
        guestHints = enrichment.guestHints ?? guestHints
        rateDetails = BookingRateDetails.merging(existing: rateDetails, incoming: enrichment.rateDetails)
        hotelOffsetSeconds = enrichment.hotelOffsetSeconds ?? hotelOffsetSeconds
        hotelCheckInMinutes = enrichment.hotelCheckInMinutes ?? hotelCheckInMinutes
        hotelCheckOutMinutes = enrichment.hotelCheckOutMinutes ?? hotelCheckOutMinutes
        flightDepartureOffsetSeconds = enrichment.flightDepartureOffsetSeconds ?? flightDepartureOffsetSeconds
        flightArrivalOffsetSeconds = enrichment.flightArrivalOffsetSeconds ?? flightArrivalOffsetSeconds
        operatorName = enrichment.operatorName ?? operatorName
        isAllDay = enrichment.isAllDay ?? isAllDay
    }

    private mutating func assignNonEmpty(_ value: String?, to keyPath: WritableKeyPath<Self, String?>) {
        guard let value, !value.isEmpty else { return }
        self[keyPath: keyPath] = value
    }
}
