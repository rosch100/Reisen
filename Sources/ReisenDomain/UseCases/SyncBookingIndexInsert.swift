import Foundation

public enum SyncBookingIndexInsert {
    public static func insert(
        _ booking: Booking,
        intoURL: inout [String: Booking],
        intoCode: inout [String: [UUID: Booking]],
        intoFingerprint: inout [SyncBookingDateFingerprintKey: [UUID: Booking]],
        calendar: Calendar
    ) {
        if let url = booking.externalUrl {
            intoURL[url] = booking
        }
        if let code = booking.confirmationCode, !code.isEmpty {
            intoCode[code, default: [:]][booking.id] = booking
        }
        let key = SyncBookingDateFingerprint.key(for: booking, calendar: calendar)
        intoFingerprint[key, default: [:]][booking.id] = booking
    }
}
