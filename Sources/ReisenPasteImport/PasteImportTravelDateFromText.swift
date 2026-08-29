import Foundation

/// Reisedatum aus Quelltext, wenn das Modell `startAt` leer ließ.
///
/// Nimmt nur Daten direkt unter Abfahrt/Check-in/Pickup/Departure Date — auch auf derselben Zeile —
/// sowie datierte Routenzeilen (z. B. „Fr. 18. Dezember 2020: Hamburg – Frankfurt“).
/// Buchungs- und Zahlungsdatum zählen nicht.
public enum PasteImportTravelDateFromText {
    public static func startAt(in text: String) -> Date? {
        allStartAts(in: text).first
    }

    /// Geordnete Reisedaten aus dem Quelltext (Labels und Itinerar-Routenzeilen).
    public static func allStartAts(in text: String) -> [Date] {
        let lines = text
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        var dates: [Date] = []
        var seen = Set<TimeInterval>()
        func append(_ date: Date) {
            let key = date.timeIntervalSinceReferenceDate
            guard !seen.contains(key) else { return }
            seen.insert(key)
            dates.append(date)
        }
        for (index, line) in lines.enumerated() {
            if isIgnore(line) { continue }
            if let afterLabel = travelRemainder(in: line) {
                if let date = PasteImportTicketDate.parse(afterLabel) {
                    append(date)
                    continue
                }
                for next in lines.dropFirst(index + 1).prefix(3) {
                    if isIgnore(next) { break }
                    if let date = PasteImportTicketDate.parse(next) {
                        append(date)
                        break
                    }
                }
                continue
            }
            if let date = itineraryRouteDate(in: line) {
                append(date)
            }
        }
        return dates
    }

    /// `nil`, wenn die Zeile kein Reise-Label trägt; sonst der Text nach dem Label (kann leer sein).
    private static func travelRemainder(in line: String) -> String? {
        let key = letters(line)
        guard let label = travel.first(where: { key == $0 || key.hasPrefix($0) }) else {
            return nil
        }
        return remainder(after: label, in: line)
    }

    /// „Fr. 18. Dezember 2020: Hamburg – Frankfurt“ / „18 Jul 2026 Vancouver – San Francisco“.
    private static func itineraryRouteDate(in line: String) -> Date? {
        guard line.contains("–") || line.contains(" - ") || line.contains("—") else { return nil }
        let head = String(line.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            .first ?? Substring(line))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let date = PasteImportTicketDate.parse(head) { return date }
        let stripped = head.replacingOccurrences(
            of: #"^[A-Za-zÄÖÜäöü]{2,4}\.?\s+"#,
            with: "",
            options: .regularExpression
        )
        return PasteImportTicketDate.parse(stripped)
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
        "abflug",
        "checkin",
        "anreise",
        "pickup",
        "tourstart",
        "startdate",
        "reisedatum",
        "traveldate",
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
