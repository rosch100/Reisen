import Foundation

public struct CalendarTimelineComposer: Sendable {
    public init() {}

    /// Compose calendar event drafts for a set of trips/bookings based on toggles.
    public func compose(
        trips: [Trip],
        bookings: [Booking],
        bookingTitles: [UUID: String],
        includeTripStartEnd: Bool,
        includeFlightTimes: Bool,
        includeHotelStays: Bool
    ) -> [CalendarEventDraft] {
        if trips.isEmpty { return [] }

        let bookingsByID = Dictionary(uniqueKeysWithValues: bookings.map { ($0.id, $0) })

        var drafts: [CalendarEventDraft] = []
        drafts.reserveCapacity(trips.count * 4)

        for trip in trips {
            if includeTripStartEnd {
                drafts.append(contentsOf: tripStartEndDrafts(for: trip, bookingsByID: bookingsByID))
            }

            if includeFlightTimes {
                drafts.append(contentsOf: flightTimeDrafts(
                    for: trip,
                    bookingsByID: bookingsByID,
                    bookingTitles: bookingTitles
                ))
            }

            if includeHotelStays {
                drafts.append(contentsOf: hotelStayDrafts(
                    for: trip,
                    bookingsByID: bookingsByID,
                    bookingTitles: bookingTitles
                ))
            }
        }

        return drafts
    }
}

private extension CalendarTimelineComposer {
    func tripStartEndDrafts(
        for trip: Trip,
        bookingsByID: [UUID: Booking]
    ) -> [CalendarEventDraft] {
        let tzOffset = firstBookingHotelOffsetSeconds(for: trip, bookingsByID: bookingsByID)
        let tripLocationAddress = firstKnownTripAddress(for: trip, bookingsByID: bookingsByID)
        let tripLocationQuery = tripLocationAddress == nil ? trip.destination : nil

        return [
            CalendarEventDraft(
                role: .tripStart,
                ownerTripID: trip.id,
                ownerBookingID: nil,
                title: "Reisebeginn: \(trip.title)",
                startDate: trip.startDate,
                endDate: trip.startDate,
                isAllDay: true,
                timeZoneOffsetSecondsFromGMT: tzOffset,
                locationAddress: tripLocationAddress,
                locationQuery: tripLocationQuery,
                url: nil,
                notes: buildTripStartEndNotes(for: trip, bookingsByID: bookingsByID, isStart: true)
            ),
            CalendarEventDraft(
                role: .tripEnd,
                ownerTripID: trip.id,
                ownerBookingID: nil,
                title: "Reiseende: \(trip.title)",
                startDate: trip.endDate,
                endDate: trip.endDate,
                isAllDay: true,
                timeZoneOffsetSecondsFromGMT: tzOffset,
                locationAddress: tripLocationAddress,
                locationQuery: tripLocationQuery,
                url: nil,
                notes: buildTripStartEndNotes(for: trip, bookingsByID: bookingsByID, isStart: false)
            )
        ]
    }

    func flightTimeDrafts(
        for trip: Trip,
        bookingsByID: [UUID: Booking],
        bookingTitles: [UUID: String]
    ) -> [CalendarEventDraft] {
        var drafts: [CalendarEventDraft] = []
        drafts.reserveCapacity(trip.bookingIDs.count)

        for bookingID in trip.bookingIDs {
            guard let booking = bookingsByID[bookingID] else { continue }
            guard booking.bookingType == .flight else { continue }

            let displayTitle = bookingTitles[booking.id] ?? booking.bookingType.rawValue.capitalized
            let airline = booking.rateDetails?.airline?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let eventTitle = flightEventTitle(displayTitle: displayTitle, airline: airline)
            let url = booking.externalUrl.flatMap { URL(string: $0) }

            // Requirement: nur ein Termin pro Flug.
            let locationAddress = booking.locationFromAddress
            let locationQuery = booking.locationFromAddress == nil ? booking.locationFrom : nil
            let notes = buildFlightNotes(booking: booking, displayTitle: displayTitle, airline: airline)

            drafts.append(
                CalendarEventDraft(
                    role: .flightDeparture,
                    ownerTripID: trip.id,
                    ownerBookingID: booking.id,
                    title: eventTitle,
                    startDate: booking.startAt,
                    endDate: booking.startAt,
                    isAllDay: false,
                    timeZoneOffsetSecondsFromGMT: nil,
                    locationAddress: locationAddress,
                    locationQuery: locationQuery,
                    url: url,
                    notes: notes
                )
            )
        }

        return drafts
    }

    func hotelStayDrafts(
        for trip: Trip,
        bookingsByID: [UUID: Booking],
        bookingTitles: [UUID: String]
    ) -> [CalendarEventDraft] {
        var drafts: [CalendarEventDraft] = []
        drafts.reserveCapacity(trip.bookingIDs.count)

        for bookingID in trip.bookingIDs {
            guard let booking = bookingsByID[bookingID] else { continue }
            guard booking.bookingType == .hotel else { continue }

            let title = bookingTitles[booking.id] ?? booking.bookingType.rawValue.capitalized
            let url = booking.externalUrl.flatMap { URL(string: $0) }
            let locationAddress = booking.locationToAddress ?? booking.locationFromAddress
            let locationQuery: String? = (locationAddress == nil)
                ? (booking.locationTo ?? booking.locationFrom)
                : nil

            drafts.append(
                CalendarEventDraft(
                    role: .hotelStay,
                    ownerTripID: trip.id,
                    ownerBookingID: booking.id,
                    title: "Hotel: \(title)",
                    startDate: HotelStayDate.dateOnly(
                        fromStoredOrParsed: booking.startAt,
                        legacyHotelOffsetSeconds: booking.hotelOffsetSeconds
                    ),
                    endDate: HotelStayDate.dateOnly(
                        fromStoredOrParsed: booking.endAt,
                        legacyHotelOffsetSeconds: booking.hotelOffsetSeconds
                    ),
                    isAllDay: true,
                    timeZoneOffsetSecondsFromGMT: nil,
                    locationAddress: locationAddress,
                    locationQuery: locationQuery,
                    url: url,
                    notes: buildHotelNotes(booking: booking, displayTitle: title)
                )
            )
        }

        return drafts
    }

    func firstBookingHotelOffsetSeconds(
        for trip: Trip,
        bookingsByID: [UUID: Booking]
    ) -> Int? {
        trip.bookingIDs
            .compactMap { bookingsByID[$0]?.hotelOffsetSeconds }
            .first
    }

    func firstKnownTripAddress(
        for trip: Trip,
        bookingsByID: [UUID: Booking]
    ) -> String? {
        trip.bookingIDs
            .compactMap { bookingsByID[$0] }
            .compactMap { booking in
                booking.locationToAddress ?? booking.locationFromAddress
            }
            .first
    }

    func buildTripStartEndNotes(
        for trip: Trip,
        bookingsByID: [UUID: Booking],
        isStart: Bool
    ) -> String? {
        // Only hotel check-in/out times as notes.
        let hotels = trip.bookingIDs.compactMap { bookingsByID[$0] }.filter { $0.bookingType == .hotel }
        guard !hotels.isEmpty else { return nil }

        if isStart {
            guard let checkInMinutes = hotels
                .compactMap(\.hotelCheckInMinutes)
                .first
            else { return nil }
            return "Check-in: \(formatMinutes(checkInMinutes))"
        } else {
            guard let checkOutMinutes = hotels
                .compactMap(\.hotelCheckOutMinutes)
                .first
            else { return nil }
            return "Check-out: \(formatMinutes(checkOutMinutes))"
        }
    }

    func buildFlightNotes(
        booking: Booking,
        displayTitle: String,
        airline: String?
    ) -> String {
        var lines: [String] = []
        lines.append("Buchung: \(displayTitle)")
        if let airline, !airline.isEmpty {
            lines.append("Fluggesellschaft: \(airline)")
        }
        if let confirmation = booking.confirmationCode?.trimmingCharacters(in: .whitespacesAndNewlines),
           !confirmation.isEmpty {
            lines.append("Bestätigung: \(confirmation)")
        }
        return lines.joined(separator: "\n")
    }

    func flightEventTitle(displayTitle: String, airline: String?) -> String {
        if let airline, !airline.isEmpty {
            return "\(displayTitle) – \(airline)"
        }
        return displayTitle
    }

    func buildHotelNotes(booking: Booking, displayTitle: String) -> String {
        var lines: [String] = []
        lines.append("Hotel: \(displayTitle)")

        if let confirmation = booking.confirmationCode?.trimmingCharacters(in: .whitespacesAndNewlines),
           !confirmation.isEmpty {
            lines.append("Bestätigung: \(confirmation)")
        }

        if let checkInMinutes = booking.hotelCheckInMinutes {
            lines.append("Check-in: \(formatMinutes(checkInMinutes))")
        }
        if let checkOutMinutes = booking.hotelCheckOutMinutes {
            lines.append("Check-out: \(formatMinutes(checkOutMinutes))")
        }

        // No dummy lines if not available.
        return lines.joined(separator: "\n")
    }

    func formatMinutes(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        return String(format: "%02d:%02d", hours, mins)
    }
}

