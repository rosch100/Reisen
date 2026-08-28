import Foundation

extension L10n {
    public static func travellerTypeDisplay(_ type: TravellerType) -> String {
        switch type {
        case .adult: return string(.travellerAdult)
        case .child: return string(.travellerChild)
        case .infant: return string(.travellerInfant)
        case .unknown: return string(.commonUnknown)
        }
    }

    public static func baggageTypeDisplay(_ type: BaggageType) -> String {
        switch type {
        case .checkedBag: return string(.baggageChecked)
        case .cabinBag: return string(.baggageCabin)
        case .personalItem: return string(.baggagePersonal)
        case .unknown: return string(.commonUnknown)
        }
    }

    public static func baggageTypeShortDisplay(_ type: BaggageType) -> String {
        switch type {
        case .checkedBag: return string(.baggageShortChecked)
        case .cabinBag: return string(.baggageShortCabin)
        case .personalItem: return string(.baggageShortPersonal)
        case .unknown: return string(.commonUnknown)
        }
    }

    public static func gapKindDisplay(_ kind: GapKind) -> String {
        switch kind {
        case .lodging: return string(.gapKindLodging)
        case .transport: return string(.gapKindTransport)
        case .both: return string(.gapKindBoth)
        }
    }

    /// „1 Lücke“ / „n Lücken“ für Inter-Booking-Gaps.
    public static func tripCompletenessGapCount(_ count: Int) -> String {
        if count == 1 {
            return string(.tripCompletenessGapOne)
        }
        return format(.tripCompletenessGapMany, count)
    }

    /// Caption mit Gap-Arten; `nil` wenn keine Inter-Lücken oder nur `.both`.
    public static func tripCompletenessKindCaption(kinds: [GapKind]) -> String? {
        guard !kinds.isEmpty else { return nil }
        if kinds.allSatisfy({ $0 == .both }) { return nil }
        return kinds.map(gapKindDisplay).joined(separator: " · ")
    }

    public static func tripCompletenessEdgeCaption(count: Int) -> String? {
        guard count > 0 else { return nil }
        if count == 1 {
            return string(.tripCompletenessEdgeOne)
        }
        return format(.tripCompletenessEdgeMany, count)
    }

    public static func tripCompletenessUnknownCaption(count: Int) -> String? {
        guard count > 0 else { return nil }
        return format(.tripCompletenessUnknownMany, count)
    }

    public static func tripCompletenessAccessibility(_ completeness: TripCompleteness) -> String {
        if completeness.hasTimeGaps {
            return format(.tripCompletenessA11yIncomplete, completeness.interBookingGapCount)
        }
        return string(.tripCompletenessA11yComplete)
    }

    public static func tripCompletenessFillCaption(tripTitle: String) -> String {
        format(.tripCompletenessFillCaption, tripTitle)
    }

    public static func tripCompletenessSidebarLine(bookingCount: Int, gapCount: Int) -> String {
        format(.tripCompletenessSidebarWithGaps, bookingCount, gapCount)
    }

    public static func tripCompletenessOverviewFactValue(_ completeness: TripCompleteness) -> String {
        if completeness.hasTimeGaps {
            return "\(completeness.interBookingGapCount)"
        }
        return string(.tripCompletenessNoneShort)
    }

    public static func providerLoginStatusDisplay(_ status: ProviderLoginTrafficLight) -> String {
        switch status {
        case .green: return string(.loginStatusGreen)
        case .red: return string(.loginStatusRed)
        case .gray: return string(.loginStatusGray)
        }
    }

    public static func privacySettingPaneDisplay(_ pane: PrivacySettingPane) -> String {
        switch pane {
        case .calendars: return string(.privacyCalendars)
        case .reminders: return string(.privacyReminders)
        case .notifications: return string(.privacyNotifications)
        }
    }

    public static func optionalFieldLabel(_ label: String) -> String {
        format(.commonOptionalSuffix, label)
    }
}
