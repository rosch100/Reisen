import Foundation

/// Reisedatum aus Quelltext, wenn das Modell `startAt` leer ließ.
///
/// Nimmt nur Daten direkt unter Abfahrt/Check-in/Pickup/Departure Date.
/// Buchungs- und Zahlungsdatum zählen nicht.
public enum PasteImportTravelDateFromText {
    public static func startAt(in text: String) -> Date? {
        let lines = text
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        for (index, line) in lines.enumerated() {
            if isIgnore(line) { continue }
            guard isTravel(line) else { continue }
            for next in lines.dropFirst(index + 1).prefix(3) {
                if isIgnore(next) { break }
                if let date = PasteImportTicketDate.parse(next) { return date }
            }
        }
        return nil
    }

    private static func isTravel(_ line: String) -> Bool {
        let key = letters(line)
        return travel.contains(where: { key == $0 || key.hasPrefix($0) })
    }

    private static func isIgnore(_ line: String) -> Bool {
        let key = letters(line)
        return ignore.contains(where: { key == $0 || key.hasPrefix($0) })
    }

    private static func letters(_ line: String) -> String {
        line.lowercased().filter(\.isLetter)
    }

    private static let travel = [
        "departuredate",
        "departure",
        "abfahrt",
        "checkin",
        "anreise",
        "pickup",
        "tourstart",
        "startdate",
        "reisedatum",
        "eventdate",
        "date",
    ]

    private static let ignore = [
        "bookingdate",
        "buchungsdatum",
        "issueddate",
        "issued",
        "payment",
        "orderid",
        "order",
    ]
}
