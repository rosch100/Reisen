import Foundation
import ReisenDomain
import ReisenDiagnostics

enum ExpediaCatalogParser {
    static func drafts(
        fromTripItemsData data: [String: Any],
        tripViewId: String,
        diagnosticContext: DiagnosticContext? = nil
    ) async -> [ProviderBookingDraft] {
        var drafts: [ProviderBookingDraft] = []
        let cards = collectBookedCards(in: data)
        for card in cards {
            guard let identifier = ExpediaJSON.string(card["identifier"]) else {
                await skipCatalog(
                    diagnosticContext,
                    event: "skip_missing_identifier",
                    reason: "identifier"
                )
                continue
            }
            guard let bookingType = ExpediaProductType.bookingType(fromProductIdentifier: identifier) else {
                await skipCatalog(
                    diagnosticContext,
                    event: "skip_unknown_lob",
                    reason: "unknown_product_prefix"
                )
                continue
            }
            guard let detailURL = resourceURL(in: card["cardAction"]) else {
                await skipCatalog(
                    diagnosticContext,
                    event: "skip_missing_detail_url",
                    reason: bookingType.rawValue
                )
                continue
            }
            let title = ExpediaJSON.string(card["primary"])
            let badge = ExpediaJSON.dict(card["badge"]).flatMap { ExpediaJSON.string($0["text"]) }
            let statusRaw: String? = (badge?.localizedCaseInsensitiveContains("Gebucht") == true)
                ? "confirmed"
                : nil
            let secondaries = secondaryTexts(from: card)
            let manageURL = manageBookingURL(fromMenu: card["menu"]) ?? defaultManageURL(from: detailURL)
            let cancellationURL = ExpediaProductType.catalogCancellationURL(
                bookingType: bookingType,
                manageURL: manageURL
            )
            let schedule = ExpediaScheduleParser.window(fromSecondaryTexts: secondaries, bookingType: bookingType)
            guard let start = schedule?.start, let end = schedule?.end else {
                await skipCatalog(
                    diagnosticContext,
                    event: "skip_unparseable_schedule",
                    reason: bookingType.rawValue
                )
                continue
            }
            let facts = ProviderBookingFacts(
                provider: .expedia,
                bookingType: bookingType,
                start: start,
                end: end,
                title: title,
                confirmationCode: nil,
                externalUrl: detailURL,
                cancellationUrl: cancellationURL,
                locationFrom: locationHint(from: secondaries),
                locationTo: bookingType == .hotel || bookingType == .carRental
                    ? locationHint(from: secondaries)
                    : nil,
                operatorName: operatorName(from: card),
                statusRaw: statusRaw,
                hotelCheckInMinutes: schedule?.hotelCheckInMinutes,
                hotelCheckOutMinutes: schedule?.hotelCheckOutMinutes,
                rawPayloadFingerprint: "\(tripViewId)|\(identifier)|\(detailURL)"
            )
            if let draft = DraftAssembler.draft(from: facts) {
                drafts.append(draft)
            } else {
                await skipCatalog(
                    diagnosticContext,
                    event: "skip_draft_assembly",
                    reason: bookingType.rawValue
                )
            }
        }
        return drafts
    }

    private static func skipCatalog(
        _ diagnosticContext: DiagnosticContext?,
        event: String,
        reason: String
    ) async {
        guard let diagnosticContext else { return }
        await DiagnosticLogger.shared.record(
            DiagnosticEvent(
                context: diagnosticContext,
                component: "ExpediaCatalogParser",
                phase: "catalog",
                event: event,
                result: .skipped,
                reason: reason,
                visibility: .publicDiagnostic
            )
        )
    }

    private static func collectBookedCards(in root: Any) -> [[String: Any]] {
        var cards: [[String: Any]] = []
        ExpediaJSON.walkDepthFirst(root) { node in
            guard let d = node as? [String: Any] else { return }
            let typeName = ExpediaJSON.string(d["__typename"]) ?? ""
            if typeName == "TripsUIBookedItemCard" {
                cards.append(d)
            }
        }
        return cards
    }

    private static func secondaryTexts(from card: [String: Any]) -> [String] {
        texts(fromArrayKey: "enrichedSecondaries", in: card)
            + texts(fromArrayKey: "secondaries", in: card)
    }

    private static func texts(fromArrayKey key: String, in card: [String: Any]) -> [String] {
        guard let items = ExpediaJSON.array(card[key]) else { return [] }
        return items.compactMap { ExpediaJSON.dict($0).flatMap { ExpediaJSON.string($0["text"]) } }
    }

    private static func operatorName(from card: [String: Any]) -> String? {
        let logoDesc = ExpediaJSON.dict(card["logo"]).flatMap { ExpediaJSON.string($0["description"]) }
            ?? ExpediaJSON.dict(card["asset"]).flatMap { ExpediaJSON.string($0["description"]) }
        if let logoDesc, let range = logoDesc.range(of: "Logo von ", options: .caseInsensitive) {
            let name = String(logoDesc[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            return name.isEmpty ? nil : name
        }
        return nil
    }

    private static func locationHint(from texts: [String]) -> String? {
        for text in texts {
            if let range = text.range(of: " in ", options: .caseInsensitive) {
                let city = String(text[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                if !city.isEmpty { return city }
            }
        }
        return nil
    }

    private static func resourceURL(in action: Any?) -> String? {
        guard let action = ExpediaJSON.dict(action),
              let resource = ExpediaJSON.dict(action["resource"])
        else { return nil }
        return ExpediaJSON.string(resource["value"])
    }

    private static func manageBookingURL(fromMenu menu: Any?) -> String? {
        guard let menu = ExpediaJSON.dict(menu),
              let items = ExpediaJSON.array(menu["items"])
        else { return nil }
        for item in items {
            guard let dict = ExpediaJSON.dict(item) else { continue }
            let action = dict["action"] ?? dict["linkAction"]
            if let url = resourceURL(in: action), url.contains("/manage-booking") {
                return url
            }
            let referrer = ExpediaJSON.dict(ExpediaJSON.dict(action)?["analytics"])
                .flatMap { ExpediaJSON.string($0["referrerId"]) } ?? ""
            if referrer.contains("ManageTrip"), let url = resourceURL(in: action) {
                return url.contains("/manage-booking") ? url : url + "/manage-booking"
            }
        }
        return nil
    }

    private static func defaultManageURL(from detailURL: String) -> String? {
        guard let parts = ExpediaExternalURL.parts(from: detailURL) else { return nil }
        return ExpediaExternalURL.manageBookingURL(
            tripViewId: parts.tripViewId,
            tripItemId: parts.tripItemId
        )
    }
}
