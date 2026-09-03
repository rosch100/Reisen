import Foundation

/// Heuristik für Check24-KB `detail.line2` (Ort vs. Zimmertyp).
enum Check24CatalogDetailLine {
    /// DE-/Produkt-Marker als Substring; bewusst ohne generisches EN `room`/`studio`
    /// und ohne bare `apartment` (Ortszeilen wie „Apartmentviertel …“).
    private static let roomCategoryNeedles = [
        "zimmer",
        "kapsel",
        "bett",
        "suite",
        "doppel",
        "einzel",
        "mehrbett",
        "dorm",
        "gemeinschaft",
        "bungalow",
        "cabin",
        "penthouse",
        "studio apartment",
        "studioapartment",
        "hotel apartment",
        "hotelapartment",
        "ferienapartment",
        "hotelzimmer",
    ]

    static func looksLikeRoomCategory(_ raw: String) -> Bool {
        let folded = raw
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "de_DE"))
            .lowercased()
        return roomCategoryNeedles.contains { folded.contains($0) }
    }
}
