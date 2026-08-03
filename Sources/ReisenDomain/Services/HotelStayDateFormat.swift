import Foundation

public enum HotelStayDateFormat {
    public static func format(
        _ date: Date,
        dateFormat: String,
        legacyHotelOffsetSeconds: Int? = nil,
        locale: Locale = Locale(identifier: "de_DE_POSIX")
    ) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = HotelStayDate.timeZone
        formatter.dateFormat = dateFormat
        let anchor = HotelStayDate.dateOnly(
            fromStoredOrParsed: date,
            legacyHotelOffsetSeconds: legacyHotelOffsetSeconds
        )
        return formatter.string(from: anchor)
    }
}
