import Foundation

extension BookingType {
    /// Ob „Von“/Abholung angezeigt wird (Hotel/Erlebnis nur Zielort).
    public var showsLocationFrom: Bool {
        switch self {
        case .hotel, .activity:
            return false
        case .flight, .ferry, .train, .carRental, .other:
            return true
        }
    }

    public var locationFromLabel: String { L10n.locationFromLabel(for: self) }
    public var locationToLabel: String { L10n.locationToLabel(for: self) }
    public var locationFromAddressLabel: String? { L10n.locationFromAddressLabel(for: self) }
    public var locationToAddressLabel: String? { L10n.locationToAddressLabel(for: self) }
    public var roomCategoryLabel: String? { L10n.roomCategoryLabel(for: self) }
    public var roomCountLabel: String? { L10n.roomCountLabel(for: self) }
    public var operatorNameLabel: String { L10n.operatorNameLabel(for: self) }
    /// Betreiber-Feld im Editor (Typen mit eigenem Operator-Label).
    public var showsOperatorNameField: Bool {
        switch self {
        case .train, .activity, .carRental:
            return true
        case .flight, .hotel, .ferry, .other:
            return false
        }
    }

    /// Persistierter Betreiber (Provider/Enrichment). Unabhängig von Editor-Sichtbarkeit:
    /// Fähre/Andere können `operatorName` haben, ohne Editor-Feld.
    public var persistsOperatorName: Bool {
        switch self {
        case .train, .activity, .carRental, .ferry, .other:
            return true
        case .flight, .hotel:
            return false
        }
    }
    public var scheduleStartLabel: String { L10n.scheduleStartLabel(for: self) }
    public var scheduleEndLabel: String { L10n.scheduleEndLabel(for: self) }
}
