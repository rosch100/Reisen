import Foundation

extension AppSettings {
    public var calendarTimelineEnabled: Bool {
        calendarTripTimesEnabled || calendarFlightTimesEnabled || calendarHotelStaysEnabled
    }

    public var needsHotelAddressesForCalendar: Bool {
        calendarTripTimesEnabled || calendarHotelStaysEnabled
    }
}
