import Foundation

/// Reisedatum aus Quelltext, wenn das Modell `startAt` leer ließ.
///
/// Nimmt nur Daten direkt unter Abfahrt/Check-in/Pickup/Departure Date — auch auf derselben Zeile.
/// Buchungs- und Zahlungsdatum zählen nicht.
public enum PasteImportTravelDateFromText {
    public static func startAt(in text: String) -> Date? {
        let lines = text
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        for (index, line) in lines.enumerated() {
            if isIgnore(line) { continue }
            guard let afterLabel = travelRemainder(in: line) else { continue }
            if let date = PasteImportTicketDate.parse(afterLabel) { return date }
            for next in lines.dropFirst(index + 1).prefix(3) {
                if isIgnore(next) { break }
                if let date = PasteImportTicketDate.parse(next) { return date }
            }
        }
        return nil
    }

    /// `nil`, wenn die Zeile kein Reise-Label trägt; sonst der Text nach dem Label (kann leer sein).
    private static func travelRemainder(in line: String) -> String? {
        let key = letters(line)
        guard let label = travel.first(where: { key == $0 || key.hasPrefix($0) }) else {
            return nil
        }
        return remainder(after: label, in: line)
    }

    private static func isIgnore(_ line: String) -> Bool {
        let key = letters(line)
        return ignore.contains(where: { key == $0 || key.hasPrefix($0) })
    }

    private static func letters(_ line: String) -> String {
        line.lowercased().filter(\.isLetter)
    }

    /// Entfernt das erkannte Label vom Zeilenanfang und lässt Satzzeichen/Leerzeichen weg.
    private static func remainder(after labelLetters: String, in line: String) -> String {
        var letterCount = 0
        var index = line.startIndex
        while index < line.endIndex, letterCount < labelLetters.count {
            if line[index].isLetter {
                letterCount += 1
            }
            index = line.index(after: index)
        }
        return String(line[index...])
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ":·–-"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
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
    ]

    private static let ignore = [
        "bookingdate",
        "buchungsdatum",
        "issueddate",
        "issued",
        "datepaid",
        "dateofissue",
        "payment",
        "orderid",
        "order",
    ]
}
