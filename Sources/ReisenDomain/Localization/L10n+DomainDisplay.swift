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
