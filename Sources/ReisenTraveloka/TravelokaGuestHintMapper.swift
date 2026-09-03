import Foundation
import ReisenDomain
import ReisenProviders

/// Stay pre-travel hints from Traveloka hotel/lodging itinerary JSON (live 2026-08-28).
/// Structured `importantNoticePolicies` map like GYG restrictions; free-text
/// `checkInInstruction` only when `BookingGuestHintPrepKeywords` match.
/// Near-duplicate details (notices vs. `propertyPolicy`) are collapsed.
/// `specialRequests` are out of scope. No parallel linen/pet needle arrays here.
enum TravelokaGuestHintMapper {
    static func hints(
        localeInfo: [String: Any],
        bookingHotel: [String: Any],
        voucher: [String: Any]
    ) -> [BookingGuestHint] {
        let provider = ProviderID.traveloka.rawValue
        let singles = [
            propertyPolicyHint(localeInfo: localeInfo, bookingHotel: bookingHotel, provider: provider),
            checkInHint(
                localeInfo: localeInfo,
                bookingHotel: bookingHotel,
                voucher: voucher,
                provider: provider
            ),
        ].compactMap { $0 }

        return BookingGuestHint.dedupedByNormalizedDetail(
            noticePolicies(
                from: TravelokaJSON.firstDictionary([
                    localeInfo["importantNoticeDisplay"],
                    bookingHotel["importantNoticeDisplay"],
                ]),
                provider: provider
            ) + singles
        )
    }

    /// Experience: `howToUse` / `importantNote` sowie prep-relevante Freitexte aus MYOW-Infos.
    static func experienceHints(experienceDetail: [String: Any]) -> [BookingGuestHint] {
        let provider = ProviderID.traveloka.rawValue
        let myow = TravelokaJSON.dictionary(experienceDetail["makeYourOwnWayInfo"])
        let singles = [
            freeTextHint(
                title: "Anleitung",
                detail: plainText(experienceDetail["howToUse"]),
                sourceKey: "\(provider):experience:how_to_use",
                provider: provider,
                requirePrepKeywords: false
            ),
            freeTextHint(
                title: "Wichtig",
                detail: plainText(experienceDetail["importantNote"]),
                sourceKey: "\(provider):experience:important_note",
                provider: provider,
                requirePrepKeywords: false
            ),
            freeTextHint(
                title: "Zusatzinfo",
                detail: plainText(
                    myow["experienceExtraInformation"],
                    flattenComponentTree(myow["extraInformation"])
                ),
                sourceKey: "\(provider):experience:extra_information",
                provider: provider,
                requirePrepKeywords: true
            ),
        ].compactMap { $0 }
        return BookingGuestHint.dedupedByNormalizedDetail(singles)
    }

    private static func freeTextHint(
        title: String,
        detail: String?,
        sourceKey: String,
        provider: String,
        requirePrepKeywords: Bool
    ) -> BookingGuestHint? {
        guard let detail else { return nil }
        if requirePrepKeywords, !BookingGuestHintPrepKeywords.matches(detail) {
            return nil
        }
        return makeHint(title: title, detail: detail, sourceKey: sourceKey, provider: provider)
    }

    /// Traveloka Experience-UI-Bäume: sichtbare Strings aus verschachtelten Components sammeln.
    private static func flattenComponentTree(_ value: Any?) -> String? {
        var parts: [String] = []
        collectPlainStrings(from: value, into: &parts)
        return NonEmpty.string(parts.joined(separator: "\n"))
    }

    private static let componentDisplayKeys: Set<String> = [
        "text", "value", "content", "title", "description",
    ]

    private static func collectPlainStrings(from value: Any?, into parts: inout [String]) {
        switch value {
        case let text as String:
            if let trimmed = NonEmpty.string(HTMLPlainText.flatten(text)) {
                parts.append(trimmed)
            }
        case let dict as [String: Any]:
            for key in componentDisplayKeys {
                if let trimmed = NonEmpty.string(HTMLPlainText.flatten(TravelokaJSON.string(dict[key]) ?? "")) {
                    parts.append(trimmed)
                }
            }
            for (key, nested) in dict where !componentDisplayKeys.contains(key) {
                collectPlainStrings(from: nested, into: &parts)
            }
        case let list as [Any]:
            for nested in list {
                collectPlainStrings(from: nested, into: &parts)
            }
        default:
            break
        }
    }

    private static func noticePolicies(
        from display: [String: Any],
        provider: String
    ) -> [BookingGuestHint] {
        let policies = display["importantNoticePolicies"] as? [[String: Any]] ?? []
        return policies.compactMap { policy in
            guard let title = NonEmpty.string(TravelokaJSON.string(policy["policyTitle"])),
                  let detail = plainText(policy["policyDescription"])
            else { return nil }
            let type = NonEmpty.string(TravelokaJSON.string(policy["policyType"]))
            return makeHint(
                title: title,
                detail: detail,
                sourceKey: noticeSourceKey(provider: provider, type: type, title: title, detail: detail),
                provider: provider
            )
        }
    }

    private static func noticeSourceKey(
        provider: String,
        type: String?,
        title: String,
        detail: String
    ) -> String {
        ([provider, "notice", type, title, detail] as [String?])
            .compactMap { $0 }
            .joined(separator: ":")
    }

    private static func propertyPolicyHint(
        localeInfo: [String: Any],
        bookingHotel: [String: Any],
        provider: String
    ) -> BookingGuestHint? {
        guard let policy = plainText(localeInfo["propertyPolicy"], bookingHotel["propertyPolicy"]) else {
            return nil
        }
        return makeHint(
            title: "Hausregeln",
            detail: policy,
            sourceKey: "\(provider):property_policy",
            provider: provider
        )
    }

    private static func checkInHint(
        localeInfo: [String: Any],
        bookingHotel: [String: Any],
        voucher: [String: Any],
        provider: String
    ) -> BookingGuestHint? {
        guard let instruction = plainText(
            localeInfo["checkInInstruction"],
            bookingHotel["checkInInstruction"],
            voucher["checkInInstruction"]
        ), BookingGuestHintPrepKeywords.matches(instruction) else {
            return nil
        }
        return makeHint(
            title: "Check-in",
            detail: instruction,
            sourceKey: "\(provider):check_in_instruction:prep",
            provider: provider
        )
    }

    private static func makeHint(
        title: String,
        detail: String,
        sourceKey: String,
        provider: String
    ) -> BookingGuestHint {
        BookingGuestHint(
            category: .preTravelImportant,
            title: title,
            detail: detail,
            sourceKey: sourceKey,
            providerRaw: provider
        )
    }

    private static func plainText(_ values: Any?...) -> String? {
        guard let raw = TravelokaJSON.firstString(values) else { return nil }
        return NonEmpty.string(HTMLPlainText.flatten(raw))
    }
}
