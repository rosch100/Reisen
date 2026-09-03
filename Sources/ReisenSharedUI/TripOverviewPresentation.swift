import Foundation

public enum TripOverviewField: Equatable, Hashable, Sendable {
    case title
    case destination
    case period
    case cost
    case completeness
    case notes
}

public enum TripOverviewPresentation {
    public static func visibleFields(
        hasDestination: Bool,
        hasBookings: Bool,
        hasNotes: Bool
    ) -> [TripOverviewField] {
        var fields: [TripOverviewField] = [.title]
        if hasDestination { fields.append(.destination) }
        fields.append(contentsOf: [.period, .cost])
        if hasBookings { fields.append(.completeness) }
        if hasNotes { fields.append(.notes) }
        return fields
    }
}
