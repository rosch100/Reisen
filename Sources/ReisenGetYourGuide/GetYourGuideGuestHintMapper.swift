import Foundation
import ReisenDomain

/// Maps GetYourGuide bookingSummary activity fields → pre-travel guest hints.
public enum GetYourGuideGuestHintMapper {
    public static func hints(from activity: GetYourGuideGuestHintActivity) -> [BookingGuestHint] {
        var hints: [BookingGuestHint] = []
        let provider = ProviderID.getYourGuide.rawValue

        if let description = nonEmpty(activity.meetingPointDescription) {
            var detail = description
            if let minutes = activity.meetingPointMinutesBefore, minutes > 0 {
                detail += " (bitte \(minutes) Min. früher da sein)"
            }
            hints.append(
                BookingGuestHint(
                    category: .preTravelImportant,
                    title: "Treffpunkt",
                    detail: detail,
                    sourceKey: "gyg:meetingPoint",
                    providerRaw: provider
                )
            )
        }

        for restriction in activity.restrictions {
            guard let text = nonEmpty(restriction) else { continue }
            hints.append(
                BookingGuestHint(
                    category: .preTravelImportant,
                    title: "Einschränkungen",
                    detail: text,
                    sourceKey: "gyg:restriction:\(text)",
                    providerRaw: provider
                )
            )
        }

        let inclusions = activity.inclusions.compactMap(nonEmpty)
        if !inclusions.isEmpty {
            hints.append(
                BookingGuestHint(
                    category: .preTravelImportant,
                    title: "Inklusivleistungen",
                    detail: inclusions.joined(separator: ", "),
                    sourceKey: "gyg:inclusions",
                    providerRaw: provider
                )
            )
        }

        if activity.isMobileVoucherAccepted == true {
            hints.append(
                BookingGuestHint(
                    category: .preTravelImportant,
                    title: "Mobiler Voucher",
                    detail: "Mobiler Voucher wird akzeptiert — Ticket in der App bereithalten.",
                    sourceKey: "gyg:mobileVoucher",
                    providerRaw: provider
                )
            )
        }

        for item in activity.importantItineraryLines {
            guard let text = nonEmpty(item) else { continue }
            hints.append(
                BookingGuestHint(
                    category: .preTravelImportant,
                    title: "Ablauf",
                    detail: text,
                    sourceKey: "gyg:itinerary:\(text)",
                    providerRaw: provider
                )
            )
        }

        return hints
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
}

public struct GetYourGuideGuestHintActivity: Equatable, Sendable {
    public var meetingPointDescription: String?
    public var meetingPointMinutesBefore: Int?
    public var restrictions: [String]
    public var inclusions: [String]
    public var isMobileVoucherAccepted: Bool?
    public var importantItineraryLines: [String]

    public init(
        meetingPointDescription: String? = nil,
        meetingPointMinutesBefore: Int? = nil,
        restrictions: [String] = [],
        inclusions: [String] = [],
        isMobileVoucherAccepted: Bool? = nil,
        importantItineraryLines: [String] = []
    ) {
        self.meetingPointDescription = meetingPointDescription
        self.meetingPointMinutesBefore = meetingPointMinutesBefore
        self.restrictions = restrictions
        self.inclusions = inclusions
        self.isMobileVoucherAccepted = isMobileVoucherAccepted
        self.importantItineraryLines = importantItineraryLines
    }
}
