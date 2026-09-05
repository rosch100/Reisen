import Foundation
import SwiftUI
import ReisenDomain
import ReisenData

public enum OpenBookingCreateTripAction {
    public static func seed(
        fromIDs bookingIDs: Set<UUID>,
        in bookings: [SDBooking],
        locale: Locale = .current,
        calendar: Calendar = HotelStayDate.calendar,
        now: Date = Date()
    ) -> TripCreateSeed? {
        let selected = bookings.filter { bookingIDs.contains($0.id) }
        return makeSeed(
            from: OpenBookingMatching.listedUnassigned(
                in: selected,
                now: now
            ),
            locale: locale,
            calendar: calendar
        )
    }

    public static func seed(
        from bookings: [SDBooking],
        locale: Locale = .current,
        calendar: Calendar = HotelStayDate.calendar,
        now: Date = Date()
    ) -> TripCreateSeed? {
        makeSeed(
            from: OpenBookingMatching.openUnassigned(
                in: bookings,
                now: now
            ),
            locale: locale,
            calendar: calendar
        )
    }

    public static func dateRangeText(
        for bookings: [SDBooking],
        calendar: Calendar = HotelStayDate.calendar
    ) -> String? {
        TripDateBounds.formattedAbbreviatedRange(
            from: domainBookings(from: bookings),
            calendar: calendar
        )
    }

    /// Sets `seed` from every upcoming unassigned booking (`openUnassigned`).
    @discardableResult
    public static func assignSeedFromAll(
        in bookings: [SDBooking],
        seed seedBinding: Binding<TripCreateSeed?>,
        showFailed: Binding<Bool>,
        locale: Locale = .current,
        calendar: Calendar = HotelStayDate.calendar,
        now: Date = Date()
    ) -> Bool {
        assign(
            seed(from: bookings, locale: locale, calendar: calendar, now: now),
            to: seedBinding,
            showFailed: showFailed
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
        calendar: Calendar = HotelStayDate.calendar,
        now: Date = Date()
    ) -> Bool {
        assign(
            seed(
                fromIDs: bookingIDs,
                in: bookings,
                locale: locale,
                calendar: calendar,
                now: now
            ),
            to: seedBinding,
            showFailed: showFailed
        )
    }

    private static func assign(
        _ newSeed: TripCreateSeed?,
        to seedBinding: Binding<TripCreateSeed?>,
        showFailed: Binding<Bool>
    ) -> Bool {
        guard let newSeed else {
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
        from bookings: [SDBooking],
        locale: Locale,
        calendar: Calendar
    ) -> TripCreateSeed? {
        makeSeed(from: domainBookings(from: bookings), locale: locale, calendar: calendar)
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
            endDate: bounds.end,
            bookingIDs: Set(bookings.map(\.id))
        )
    }
}
