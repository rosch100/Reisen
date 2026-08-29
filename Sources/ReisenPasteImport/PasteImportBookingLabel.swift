import Foundation
import ReisenDomain

/// DE/EN-Bezeichner → Domain-Label. Unbekannt bleibt `nil`, nie `.other`.
enum PasteImportBookingLabel {
    static func bookingType(from raw: String) -> BookingType? {
        guard let key = normalize(raw) else { return nil }
        return bookingTypes[key]
    }

    /// Enge Titel-Hints ohne Modellkontext (Bus/Tour/GYG) — nicht die breite Generable-Map.
    static func typeHint(fromToken token: String) -> BookingType? {
        typeHintAliases[token]
    }

    static func status(from raw: String) -> BookingStatus? {
        guard let key = normalize(raw) else { return nil }
        return statuses[key]
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
        map.merge(typeHintAliases) { _, new in new }
        map["tgv"] = .train
        map["sncf"] = .train
        map["event"] = .activity
        map["ereignis"] = .activity
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

    /// Whitelist für `typeHint(fromToken:)` — SSOT auch in `bookingTypes` eingebunden.
    private static let typeHintAliases: [String: BookingType] = [
        "bus": .train,
        "flixbus": .train,
        "fernbus": .train,
        "coach": .train,
        "omnibus": .train,
        "tour": .activity,
        "getyourguide": .activity,
        "ausflug": .activity,
    ]

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
        let folded = PasteImportTextTokens.normalize(trimmed)
        return NonEmpty.string(folded.filter { $0.isLetter || $0.isNumber })
    }
}
