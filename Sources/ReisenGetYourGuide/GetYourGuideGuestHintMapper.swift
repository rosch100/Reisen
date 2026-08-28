import Foundation
import ReisenDomain

/// Maps GetYourGuide bookingSummary activity fields → pre-travel guest hints.
public enum GetYourGuideGuestHintMapper {
    public static func hints(from activity: GetYourGuideGuestHintActivity) -> [BookingGuestHint] {
        var hints: [BookingGuestHint] = []

        if let description = GetYourGuideParsing.trimmedNonEmpty(activity.meetingPointDescription) {
            var detail = description
            if let minutes = activity.meetingPointMinutesBefore, minutes > 0 {
                detail += " (bitte \(minutes) Min. früher da sein)"
            }
            hints.append(hint(title: "Treffpunkt", detail: detail, sourceKey: "gyg:meetingPoint"))
        }

        for restriction in activity.restrictions {
            guard let text = GetYourGuideParsing.trimmedNonEmpty(restriction) else { continue }
            hints.append(hint(title: "Einschränkungen", detail: text, sourceKey: "gyg:restriction:\(text)"))
        }

        let inclusions = activity.inclusions.compactMap(GetYourGuideParsing.trimmedNonEmpty)
        if !inclusions.isEmpty {
            hints.append(
                hint(
                    title: "Inklusivleistungen",
                    detail: inclusions.joined(separator: ", "),
                    sourceKey: "gyg:inclusions"
                )
            )
        }

        if activity.isMobileVoucherAccepted == true {
            hints.append(
                hint(
                    title: "Mobiler Voucher",
                    detail: "Mobiler Voucher wird akzeptiert — Ticket in der App bereithalten.",
                    sourceKey: "gyg:mobileVoucher"
                )
            )
        }

        for item in activity.importantItineraryLines {
            guard let text = GetYourGuideParsing.trimmedNonEmpty(item) else { continue }
            hints.append(hint(title: "Ablauf", detail: text, sourceKey: "gyg:itinerary:\(text)"))
        }

        return hints
    }

    private static func hint(title: String, detail: String, sourceKey: String) -> BookingGuestHint {
        BookingGuestHint(
            category: .preTravelImportant,
            title: title,
            detail: detail,
            sourceKey: sourceKey,
            providerRaw: ProviderID.getYourGuide.rawValue
        )
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