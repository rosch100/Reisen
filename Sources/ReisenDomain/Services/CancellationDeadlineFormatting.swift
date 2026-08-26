import Foundation

public enum CancellationDeadlineFormatting {
    public static func timeZone(for deadline: CancellationDeadline, fallback: TimeZone) -> TimeZone {
        guard let offsetSeconds = deadline.hotelOffsetSeconds else { return fallback }
        return TimeZone(secondsFromGMT: offsetSeconds) ?? fallback
    }

    public static func formatOrtszeit(
        _ date: Date,
        dateFormat: String,
        timeZone: TimeZone
    ) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "de_DE_POSIX")
        df.timeZone = timeZone
        df.dateFormat = dateFormat
        return df.string(from: date)
    }
}
