import Foundation

/// Kategorie einer Gap-Such-URL (nicht aus lokalisiertem Titel abgeleitet).
public enum GapSearchCategory: String, Sendable, Equatable, CaseIterable {
    case hotel
    case flight
    case ferry
    case activity
    case carRental

    public func isVisible(for gapKind: GapKind) -> Bool {
        switch gapKind {
        case .lodging:
            return self == .hotel || self == .activity
        case .transport:
            return self == .flight || self == .ferry || self == .carRental
        case .both:
            return true
        }
    }

    public func localizedTitle(providerDisplayName: String) -> String {
        L10n.format(searchTitleKey, providerDisplayName)
    }

    public var sectionTitle: String {
        L10n.string(sectionTitleKey)
    }

    private var searchTitleKey: L10nKey {
        switch self {
        case .hotel: return .gapSearchHotel
        case .flight: return .gapSearchFlight
        case .ferry: return .gapSearchFerry
        case .activity: return .gapSearchActivity
        case .carRental: return .gapSearchCarRental
        }
    }

    private var sectionTitleKey: L10nKey {
        switch self {
        case .hotel: return .gapSearchCategoryHotel
        case .flight: return .gapSearchCategoryFlight
        case .ferry: return .gapSearchCategoryFerry
        case .activity: return .gapSearchCategoryActivity
        case .carRental: return .gapSearchCategoryCarRental
        }
    }
}
