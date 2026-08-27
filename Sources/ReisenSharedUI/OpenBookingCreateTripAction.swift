import Foundation
import SwiftUI
import ReisenDomain
import ReisenData

public enum OpenBookingCreateTripAction {
    public static func seed(
        fromIDs bookingIDs: Set<UUID>,
        in bookings: [SDBooking],
        locale: Locale = .current,
        calendar: Calendar = .current
    ) -> TripCreateSeed? {
        seed(
            from: bookings.filter { bookingIDs.contains($0.id) },
            locale: locale,
            calendar: calendar
        )
    }

    public static func seed(
        from bookings: [SDBooking],
        locale: Locale = .current,
        calendar: Calendar = .current
    ) -> TripCreateSeed? {
        let openUnassigned = OpenBookingMatching.openUnassigned(in: bookings, calendar: calendar)
        guard !openUnassigned.isEmpty else { return nil }
        return makeSeed(
            from: domainBookings(from: openUnassigned),
            locale: locale,
            calendar: calendar
        )
    }

    public static func dateRangeText(
        for bookings: [SDBooking],
        calendar: Calendar = .current
    ) -> String {
        TripDateBounds.formattedAbbreviatedRange(
            from: domainBookings(from: bookings),
            calendar: calendar
        ) ?? ""
    }

    /// Sets `seed` from every open unassigned booking in `bookings`.
    @discardableResult
    public static func assignSeedFromAll(
        in bookings: [SDBooking],
        seed seedBinding: Binding<TripCreateSeed?>,
        showFailed: Binding<Bool>,
        locale: Locale = .current,
        calendar: Calendar = .current
    ) -> Bool {
        let openUnassigned = OpenBookingMatching.openUnassigned(in: bookings, calendar: calendar)
        return assignSeed(
            fromIDs: Set(openUnassigned.map(\.id)),
            in: bookings,
            seed: seedBinding,
            showFailed: showFailed,
            locale: locale,
            calendar: calendar
        )
    }

    /// Sets `seed` or toggles `showFailed`; returns whether a seed was created.
    @discardableResult
    public static func assignSeed(
        fromIDs bookingIDs: Set<UUID>,
        in bookings: [SDBooking],
        seed seedBinding: Binding<TripCreateSeed?>,
        showFailed: Binding<Bool>,
        locale: Locale = .current,
        calendar: Calendar = .current
    ) -> Bool {
        guard let newSeed = seed(
            fromIDs: bookingIDs,
            in: bookings,
            locale: locale,
            calendar: calendar
        ) else {
            showFailed.wrappedValue = true
            return false
        }
        seedBinding.wrappedValue = newSeed
        return true
    }

    private static func domainBookings(from bookings: [SDBooking]) -> [Booking] {
        bookings.map(DomainMapper.booking(from:))
    }

    private static func makeSeed(
        from bookings: [Booking],
        locale: Locale,
        calendar: Calendar
    ) -> TripCreateSeed? {
        guard let bounds = TripDateBounds.from(bookings: bookings, calendar: calendar) else {
            return nil
        }
        let title = TripTitleSuggestion.from(bookings: bookings, locale: locale)
        return TripCreateSeed(
            title: title,
            startDate: bounds.start,
            endDate: bounds.end
        )
    }
}
