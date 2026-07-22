import Foundation

public struct SyncProviderBookingsResult: Equatable, Sendable {
    public var bookingsPersisted: Int
    public var deadlinesPersisted: Int

    public init(bookingsPersisted: Int, deadlinesPersisted: Int) {
        self.bookingsPersisted = bookingsPersisted
        self.deadlinesPersisted = deadlinesPersisted
    }
}

public enum SyncProviderBookingsError: LocalizedError, Equatable, Sendable {
    case noBookingsFound
    case noDeadlinesFound(foundBookings: Int)

    public var errorDescription: String? {
        switch self {
        case .noBookingsFound:
            return "Keine Buchungen gefunden."
        case .noDeadlinesFound(let foundBookings):
            return "Keine Stornofristen gefunden (foundBookings=\(foundBookings))."
        }
    }
}

/// Persists provider catalog drafts into the canonical booking store.
@MainActor
public final class SyncProviderBookings {
    private let bookingRepository: any BookingRepository
    private let normalizer: BookingTimeNormalizer

    private struct DateFingerprintKey: Hashable {
        let bookingType: BookingType
        let startDay: Date
        let endDay: Date
    }

    public init(
        bookingRepository: any BookingRepository,
        normalizer: BookingTimeNormalizer = BookingTimeNormalizer()
    ) {
        self.bookingRepository = bookingRepository
        self.normalizer = normalizer
    }

    public func execute(
        provider: ProviderID,
        drafts: [ProviderBookingDraft],
        requiresDeadlines: Bool,
        now: Date = Date()
    ) throws -> SyncProviderBookingsResult {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: now)

        // Leerer Katalog = Provider hat keine zukünftigen Buchungen mehr (z. B. alle storniert).
        // Trotzdem reconcilen, sonst bleiben lokale Einträge stehen.
        guard !drafts.isEmpty else {
            try bookingRepository.deleteProviderBookings(
                provider: provider,
                keepingExternalURLs: [],
                from: startOfToday
            )
            try bookingRepository.save()
            return SyncProviderBookingsResult(bookingsPersisted: 0, deadlinesPersisted: 0)
        }

        let existing = try bookingRepository.fetch(provider: provider, from: startOfToday)

        var existingByURL: [String: Booking] = [:]
        var existingByConfirmationCode: [String: [UUID: Booking]] = [:]
        var existingByDateFingerprint: [DateFingerprintKey: [UUID: Booking]] = [:]

        for booking in existing {
            if let url = booking.externalUrl {
                existingByURL[url] = booking
            }

            if let code = booking.confirmationCode, !code.isEmpty {
                existingByConfirmationCode[code, default: [:]][booking.id] = booking
            }

            let bounds = dayBounds(
                calendar: calendar,
                bookingType: booking.bookingType,
                startAt: booking.startAt,
                endAt: booking.endAt,
                hotelOffsetSeconds: booking.hotelOffsetSeconds
            )
            let key = DateFingerprintKey(
                bookingType: booking.bookingType,
                startDay: bounds.0,
                endDay: bounds.1
            )
            existingByDateFingerprint[key, default: [:]][booking.id] = booking
        }

        var deadlinesPersisted = 0
        var keptURLs = Set<String>()

        // dayBounds/normalizedDateFingerprint/matchExistingBooking are extracted helpers.

        for draft in drafts {
            guard let externalUrl = draft.externalUrl else {
                throw RepositoryError.invalidState("Buchung ohne externalUrl kann nicht upserted werden.")
            }
            keptURLs.insert(externalUrl)

            let matched = matchExistingBooking(
                draft: draft,
                externalUrl: externalUrl,
                existingByURL: existingByURL,
                existingByConfirmationCode: existingByConfirmationCode,
                existingByDateFingerprint: existingByDateFingerprint,
                calendar: calendar
            )
            var booking = matched ?? Booking(
                provider: draft.provider,
                bookingType: draft.bookingType,
                startAt: draft.startAt,
                endAt: draft.endAt
            )

            booking.provider = draft.provider
            booking.bookingType = draft.bookingType
            booking.title = draft.title
            booking.confirmationCode = draft.confirmationCode
            booking.externalUrl = draft.externalUrl
            booking.startAt = draft.startAt
            booking.endAt = draft.endAt
            booking.locationFrom = draft.locationFrom
            booking.locationTo = draft.locationTo
            booking.locationFromAddress = draft.locationFromAddress
            booking.locationToAddress = draft.locationToAddress
            booking.status = draft.status
            booking.lastSyncedAt = now
            booking.rawPayloadFingerprint = draft.rawPayloadFingerprint
            booking.passengers = draft.passengers

            booking.hotelOffsetSeconds = draft.hotelOffsetSeconds ?? booking.hotelOffsetSeconds
            booking.hotelCheckInMinutes = draft.hotelCheckInMinutes ?? booking.hotelCheckInMinutes
            booking.hotelCheckOutMinutes = draft.hotelCheckOutMinutes ?? booking.hotelCheckOutMinutes
            booking.flightDepartureOffsetSeconds = draft.flightDepartureOffsetSeconds ?? booking.flightDepartureOffsetSeconds
            booking.flightArrivalOffsetSeconds = draft.flightArrivalOffsetSeconds ?? booking.flightArrivalOffsetSeconds

            if !draft.deadlines.isEmpty {
                booking.cancellationDeadlines = draft.deadlines.map { deadline in
                    var d = deadline
                    d.bookingID = booking.id
                    return d
                }
                deadlinesPersisted += draft.deadlines.count
            }

            if let rateDetails = draft.rateDetails {
                var details = rateDetails
                details.bookingID = booking.id
                booking.rateDetails = details
            }

            booking.timesNormalized = false
            booking = normalizer.normalizePendingIfPossible(booking)
            try bookingRepository.upsert(booking)
            existingByURL[externalUrl] = booking

            if let code = booking.confirmationCode, !code.isEmpty {
                existingByConfirmationCode[code, default: [:]][booking.id] = booking
            }
            let bounds = dayBounds(
                calendar: calendar,
                bookingType: booking.bookingType,
                startAt: booking.startAt,
                endAt: booking.endAt,
                hotelOffsetSeconds: booking.hotelOffsetSeconds
            )
            let key = DateFingerprintKey(
                bookingType: booking.bookingType,
                startDay: bounds.0,
                endDay: bounds.1
            )
            existingByDateFingerprint[key, default: [:]][booking.id] = booking
        }

        // Katalog-Reconciliation vor Deadline-Gate: stornierte/entfernte Buchungen
        // müssen auch dann gelöscht werden, wenn Stornofristen fehlen.
        try bookingRepository.deleteProviderBookings(
            provider: provider,
            keepingExternalURLs: keptURLs,
            from: startOfToday
        )

        try bookingRepository.save()

        // Stornierte Buchungen haben oft keine Policies — nur aktive zählen.
        let activeDrafts = drafts.filter { $0.status != .cancelled }
        let activeDeadlines = activeDrafts.reduce(0) { $0 + $1.deadlines.count }
        if requiresDeadlines && !activeDrafts.isEmpty && activeDeadlines == 0 {
            throw SyncProviderBookingsError.noDeadlinesFound(foundBookings: drafts.count)
        }

        return SyncProviderBookingsResult(
            bookingsPersisted: drafts.count,
            deadlinesPersisted: deadlinesPersisted
        )
    }

    private func dayBounds(
        calendar: Calendar,
        bookingType: BookingType,
        startAt: Date,
        endAt: Date,
        hotelOffsetSeconds: Int?
    ) -> (Date, Date) {
        if bookingType == .hotel {
            return (
                HotelStayDate.dateOnly(fromStoredOrParsed: startAt, legacyHotelOffsetSeconds: hotelOffsetSeconds),
                HotelStayDate.dateOnly(fromStoredOrParsed: endAt, legacyHotelOffsetSeconds: hotelOffsetSeconds)
            )
        }
        return (calendar.startOfDay(for: startAt), calendar.startOfDay(for: endAt))
    }

    private func normalizedDateFingerprint(
        for draft: ProviderBookingDraft,
        calendar: Calendar
    ) -> DateFingerprintKey? {
        // The fingerprint fallback is used only when no stable identity (like confirmationCode) is available.
        // Normalize draft times when possible (offset fields) so the "day" comparison matches persisted bookings.
        var temp = Booking(
            provider: draft.provider,
            bookingType: draft.bookingType,
            startAt: draft.startAt,
            endAt: draft.endAt
        )
        temp.hotelOffsetSeconds = draft.hotelOffsetSeconds
        temp.hotelCheckInMinutes = draft.hotelCheckInMinutes
        temp.hotelCheckOutMinutes = draft.hotelCheckOutMinutes
        temp.timesNormalized = false

        let normalized = normalizer.normalizePendingIfPossible(temp)
        let bounds = dayBounds(
            calendar: calendar,
            bookingType: normalized.bookingType,
            startAt: normalized.startAt,
            endAt: normalized.endAt,
            hotelOffsetSeconds: normalized.hotelOffsetSeconds
        )
        return DateFingerprintKey(
            bookingType: normalized.bookingType,
            startDay: bounds.0,
            endDay: bounds.1
        )
    }

    private func matchExistingBooking(
        draft: ProviderBookingDraft,
        externalUrl: String,
        existingByURL: [String: Booking],
        existingByConfirmationCode: [String: [UUID: Booking]],
        existingByDateFingerprint: [DateFingerprintKey: [UUID: Booking]],
        calendar: Calendar
    ) -> Booking? {
        if let byURL = existingByURL[externalUrl] {
            return byURL
        }

        if let code = draft.confirmationCode,
           !code.isEmpty,
           let candidatesByCode = existingByConfirmationCode[code],
           candidatesByCode.count == 1,
           let only = candidatesByCode.values.first {
            return only
        }

        if let fingerprint = normalizedDateFingerprint(for: draft, calendar: calendar),
           let candidates = existingByDateFingerprint[fingerprint],
           candidates.count == 1,
           let only = candidates.values.first {
            return only
        }

        return nil
    }
}
