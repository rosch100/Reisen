import Foundation

public enum CalendarTimelineFlightNotes {
    public static func eventTitle(displayTitle: String, airline: String?) -> String {
        if let airline, !airline.isEmpty {
            return "\(displayTitle) – \(airline)"
        }
        return displayTitle
    }

    public static func build(
        booking: Booking,
        displayTitle: String,
        airline: String?
    ) -> String {
        var lines: [String] = ["Buchung: \(displayTitle)"]
        if let airline, !airline.isEmpty {
            lines.append("Fluggesellschaft: \(airline)")
        }
        if let confirmation = booking.confirmationCode?.trimmingCharacters(in: .whitespacesAndNewlines),
           !confirmation.isEmpty {
            lines.append("Bestätigung: \(confirmation)")
        }
        return lines.joined(separator: "\n")
    }
}
