import Foundation
import ReisenDomain

/// DE/EN-Bezeichner → Domain-Label. Unbekannt bleibt `nil`, nie `.other`.
enum PasteImportBookingLabel {
    static func bookingType(from raw: String) -> BookingType? {
        guard let key = normalize(raw) else { return nil }
        return bookingTypes[key]
    }

    static func status(from raw: String) -> BookingStatus? {
        guard let key = normalize(raw) else { return nil }
        return statuses[key]
    }

    static var bookingTypeGuide: String {
        "Genau eines von: \(list(BookingType.allCases)). "
            + "Tour/Event/GetYourGuide = activity (nicht hotel). "
            + "Zug/Bahn/ICE/Trainline = train. Mietwagen/Sixt/Hertz = carRental."
    }

    static var statusGuide: String {
        "Genau eines von: \(list(BookingStatus.allCases)). bestätigt/booked = confirmed."
    }

    static var startAtGuide: String {
        "Reisebeginn als ISO8601: Abfahrt, Check-in, Pickup oder Tourstart — nicht das Buchungsdatum. "
            + "Beispiel 2026-08-28T10:00:00Z. Ohne belegte Zeitzone lokale Uhrzeit ohne Z, "
            + "z. B. 2026-08-08T07:45:00."
    }

    private static func list<Label: RawRepresentable>(_ cases: [Label]) -> String
    where Label.RawValue == String {
        cases.map(\.rawValue).joined(separator: ", ")
    }

    private static let bookingTypes: [String: BookingType] = {
        var map: [String: BookingType] = [:]
        for type in BookingType.allCases {
            if let key = normalize(type.rawValue) { map[key] = type }
        }
        map["flug"] = .flight
        map["fluge"] = .flight
        map["airline"] = .flight
        map["luft"] = .flight
        map["zug"] = .train
        map["bahn"] = .train
        map["trains"] = .train
        map["railway"] = .train
        map["rail"] = .train
        map["ice"] = .train
        map["tour"] = .activity
        map["event"] = .activity
        map["ereignis"] = .activity
        map["ausflug"] = .activity
        map["aktivitat"] = .activity
        map["aktivitaet"] = .activity
        map["unterkunft"] = .hotel
        map["accommodation"] = .hotel
        map["lodging"] = .hotel
        map["mietwagen"] = .carRental
        map["rentalcar"] = .carRental
        map["carhire"] = .carRental
        map["autovermietung"] = .carRental
        map["fahre"] = .ferry
        map["faehre"] = .ferry
        return map
    }()

    private static let statuses: [String: BookingStatus] = {
        var map: [String: BookingStatus] = [:]
        for status in BookingStatus.allCases {
            if let key = normalize(status.rawValue) { map[key] = status }
        }
        map["bestatigt"] = .confirmed
        map["bestaetigt"] = .confirmed
        map["gebucht"] = .confirmed
        map["booked"] = .confirmed
        map["storniert"] = .cancelled
        map["canceled"] = .cancelled
        return map
    }()

    private static func normalize(_ raw: String) -> String? {
        guard let trimmed = NonEmpty.string(raw) else { return nil }
        let folded = trimmed.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        let squeezed = folded.filter { $0.isLetter || $0.isNumber }
        return NonEmpty.string(squeezed.lowercased())
    }
}
