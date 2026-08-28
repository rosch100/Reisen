import Foundation

public enum DeepLinkIssue: LocalizedError, Equatable, Sendable {
    case missingDestinationHint
    case destinationIdNotDerivable
    case missingFromIATA
    case missingToIATA

    public var errorDescription: String? {
        switch self {
        case .missingDestinationHint:
            return L10n.string(.deep_linkMissingDestination)
        case .destinationIdNotDerivable:
            return L10n.string(.deep_linkMissingDestinationId)
        case .missingFromIATA:
            return L10n.string(.deep_linkMissingDepartureIata)
        case .missingToIATA:
            return L10n.string(.deep_linkMissingArrivalIata)
        }
    }

    /// Kategorien, für die dieses Issue fachlich relevant ist (für GapKind-Filter).
    public var relevantCategories: Set<GapSearchCategory> {
        switch self {
        case .missingDestinationHint, .destinationIdNotDerivable:
            return [.hotel, .activity]
        case .missingFromIATA, .missingToIATA:
            return [.flight]
        }
    }

    public func isVisible(for gapKind: GapKind) -> Bool {
        relevantCategories.contains { $0.isVisible(for: gapKind) }
    }
}

public struct DeepLinkSuggestion: Equatable, Sendable {
    public var title: String
    public var url: URL?
    public var category: GapSearchCategory
    public var providerID: ProviderID

    public init(
        title: String,
        url: URL?,
        category: GapSearchCategory,
        providerID: ProviderID
    ) {
        self.title = title
        self.url = url
        self.category = category
        self.providerID = providerID
    }

    /// Convenience: lokalisierten Titel aus Kategorie + Provider ableiten.
    public init(
        category: GapSearchCategory,
        providerID: ProviderID,
        url: URL?
    ) {
        self.title = category.localizedTitle(providerDisplayName: providerID.displayName)
        self.url = url
        self.category = category
        self.providerID = providerID
    }
}

public struct GapContext: Equatable, Sendable {
    public var gapStart: Date
    public var gapEnd: Date
    public var kind: GapKind
    public var fromLocationFrom: String?
    public var fromLocationTo: String?
    public var toLocationFrom: String?
    public var toLocationTo: String?

    public init(
        gapStart: Date,
        gapEnd: Date,
        kind: GapKind,
        fromLocationFrom: String?,
        fromLocationTo: String?,
        toLocationFrom: String?,
        toLocationTo: String?
    ) {
        self.gapStart = gapStart
        self.gapEnd = gapEnd
        self.kind = kind
        self.fromLocationFrom = fromLocationFrom
        self.fromLocationTo = fromLocationTo
        self.toLocationFrom = toLocationFrom
        self.toLocationTo = toLocationTo
    }

    public init(gap: ComputedGap, kind: GapKind? = nil) {
        self.init(
            gapStart: gap.gapStart,
            gapEnd: gap.gapEnd,
            kind: kind ?? gap.kind,
            fromLocationFrom: gap.fromBooking.locationFrom,
            fromLocationTo: gap.fromBooking.locationTo,
            toLocationFrom: gap.toBooking.locationFrom,
            toLocationTo: gap.toBooking.locationTo
        )
    }
}
