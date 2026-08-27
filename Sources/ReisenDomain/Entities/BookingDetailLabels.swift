import Foundation

/// Gemeinsame UI-Bezeichner für Buchungsdetails (provider-unabhängig, lokalisiert).
public enum BookingDetailLabels {
    public static var status: String { L10n.string(.bookingDetailStatus) }
    public static var price: String { L10n.string(.bookingDetailPrice) }
    public static var currency: String { L10n.string(.bookingDetailCurrency) }
    public static var guests: String { L10n.string(.bookingDetailGuests) }
    public static var airline: String { L10n.string(.bookingDetailAirline) }
    public static var passengers: String { L10n.string(.bookingDetailPassengers) }
    public static var baggage: String { L10n.string(.bookingDetailBaggage) }
    public static var boardType: String { L10n.string(.bookingDetailBoardType) }
    public static var breakfastIncluded: String { L10n.string(.bookingDetailBreakfastIncluded) }
    public static var allDay: String { L10n.string(.bookingDetailAllDay) }
    public static var checkIn: String { L10n.string(.bookingDetailCheckIn) }
    public static var checkOut: String { L10n.string(.bookingDetailCheckOut) }
    public static var rateLastParsed: String { L10n.string(.bookingDetailRateLastParsed) }
    public static var roomItemsSection: String { L10n.string(.bookingDetailRoomItemsSection) }
    public static var rateSection: String { L10n.string(.bookingDetailRateSection) }
    public static var cancellationSection: String { L10n.string(.bookingDetailCancellationSection) }
    public static var strictDeadline: String { L10n.string(.bookingDetailStrictDeadline) }
    public static var confirmationNumber: String { L10n.string(.bookingDetailConfirmationNumber) }
    public static var unitPrice: String { L10n.string(.bookingDetailUnitPrice) }
    public static var cancellationFree: String { L10n.string(.bookingDetailCancellationFree) }
    public static var cancellationPaid: String { L10n.string(.bookingDetailCancellationPaid) }
    public static var notAvailable: String { L10n.string(.commonNotAvailable) }
    public static var dateRange: String { L10n.string(.bookingDetailDateRange) }

    public static func yesNo(_ value: Bool) -> String {
        L10n.yesNo(value)
    }
}
