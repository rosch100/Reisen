import Foundation
import ReisenDomain

/// Extrahiert Storno-Fristen aus der Refund-Presubmission-HTML (`__NEXT_DATA__`).
enum TravelokaRefundPresubmissionParser {
    private static let freeDeadlineKeys: Set<String> = [
        "freeCancellationDeadlineLocal",
        "freeCancellationDeadline",
    ]

    private static let feeDeadlineKeys: Set<String> = [
        "refundDeadlineLocal",
        "cancellationDeadlineLocal",
        "cancellationDeadline",
    ]

    static func deadlines(fromHTML html: String, timeZone: TimeZone) throws -> [CancellationDeadline] {
        guard let json = extractNextDataJSON(from: html) else {
            throw TravelokaProviderError.invalidResponse
        }
        let root = try TravelokaJSON.object(from: json)
        var candidates: [DeadlineLocal] = []
        collectDeadlineLocals(from: root, into: &candidates)
        guard !candidates.isEmpty else {
            return []
        }

        var result: [CancellationDeadline] = []
        var seen = Set<String>()
        for item in candidates {
            let key = "\(item.isFree)|\(item.local)"
            guard seen.insert(key).inserted else { continue }
            guard let date = TravelokaJSON.localDateTime(item.local, timeZone: timeZone) else { continue }
            result.append(
                TravelokaCancellationDeadlines.at(
                    date,
                    timeZone: timeZone,
                    policyText: item.isFree ? "Free cancellation" : "Refund deadline",
                    isFreeCancellation: item.isFree,
                    feeAmount: item.feeAmount
                )
            )
        }
        return result
    }

    private struct DeadlineLocal {
        var local: String
        var isFree: Bool
        var feeAmount: Double?
    }

    private static func extractNextDataJSON(from html: String) -> String? {
        guard let startRange = html.range(of: #"id="__NEXT_DATA__""#)
                ?? html.range(of: "id='__NEXT_DATA__'")
        else {
            return nil
        }
        guard let open = html.range(of: ">", range: startRange.upperBound..<html.endIndex) else {
            return nil
        }
        guard let close = html.range(of: "</script>", range: open.upperBound..<html.endIndex) else {
            return nil
        }
        let json = String(html[open.upperBound..<close.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return json.isEmpty ? nil : json
    }

    private static func collectDeadlineLocals(from value: Any, into out: inout [DeadlineLocal]) {
        if let dict = value as? [String: Any] {
            appendDeadlines(fromSameObject: dict, into: &out)
            for child in dict.values {
                collectDeadlineLocals(from: child, into: &out)
            }
            return
        }
        if let array = value as? [Any] {
            for child in array {
                collectDeadlineLocals(from: child, into: &out)
            }
        }
    }

    /// Nur Cancel-/Refund-Deadline-Keys; Fee nur aus demselben Objekt (kein Reschedule, kein Tree-Scan).
    private static func appendDeadlines(fromSameObject dict: [String: Any], into out: inout [DeadlineLocal]) {
        for key in freeDeadlineKeys {
            if let local = TravelokaJSON.string(dict[key]) {
                out.append(DeadlineLocal(local: local, isFree: true, feeAmount: nil))
            }
        }
        for key in feeDeadlineKeys {
            if let local = TravelokaJSON.string(dict[key]) {
                out.append(
                    DeadlineLocal(
                        local: local,
                        isFree: false,
                        feeAmount: feeAmount(inSameObject: dict)
                    )
                )
            }
        }
    }

    private static func feeAmount(inSameObject dict: [String: Any]) -> Double? {
        if let amount = TravelokaJSON.double(dict["refundFeeAmount"]) { return amount }
        if let amount = TravelokaJSON.double(dict["cancellationFeeAmount"]) { return amount }
        if let amount = TravelokaJSON.double(dict["feeAmount"]) { return amount }
        if let estimation = dict["refundEstimation"] as? [String: Any] {
            return TravelokaJSON.double(estimation["amount"])
        }
        return nil
    }
}
