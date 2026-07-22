import Foundation

public enum DeepLinkIssue: LocalizedError, Equatable, Sendable {
    case missingDestinationHint
    case destinationIdNotDerivable
    case missingFromIATA
    case missingToIATA

    public var errorDescription: String? {
        switch self {
        case .missingDestinationHint:
            return "Zielhinweis fehlt (Destination/Ort konnte nicht aus Buchungen abgeleitet werden)."
        case .destinationIdNotDerivable:
            return "Aus dem Zielhinweis konnte keine Destination-ID für Hotel-Suche abgeleitet werden."
        case .missingFromIATA:
            return "Abflughafen (IATA-Code) fehlt bzw. konnte nicht extrahiert werden."
        case .missingToIATA:
            return "Ziel (IATA-Code) fehlt bzw. konnte nicht extrahiert werden."
        }
    }
}

public struct DeepLinkSuggestion: Equatable, Sendable {
    public var title: String
    public var url: URL?

    public init(title: String, url: URL?) {
        self.title = title
        self.url = url
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

    public init(gap: ComputedGap) {
        self.init(
            gapStart: gap.gapStart,
            gapEnd: gap.gapEnd,
            kind: gap.kind,
            fromLocationFrom: gap.fromBooking.locationFrom,
            fromLocationTo: gap.fromBooking.locationTo,
            toLocationFrom: gap.toBooking.locationFrom,
            toLocationTo: gap.toBooking.locationTo
        )
    }
}
