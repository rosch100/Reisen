import Foundation
import ReisenDomain

/// Führt zwei komplementäre, jeweils unvollständige **Flug-/Boarding**-Fragmente zusammen.
///
/// Beide Seiten müssen flugbezogen sein (Typ, Flugnummer oder Boarding-Titel) — kein Hotel-Code + Flug.
/// Widersprüchliche Flugnummern verhindern den Merge.
public enum PasteImportExtractionCoalescer {
    public static func coalescing(_ extractions: [PasteImportExtraction]) -> [PasteImportExtraction] {
        guard extractions.count == 2,
              let first = extractions.first,
              let second = extractions.last,
              !isFilterReady(first),
              !isFilterReady(second),
              looksLikeFlightFragment(first),
              looksLikeFlightFragment(second),
              areComplementary(first, second),
              compatibleFlightNumbers(first, second)
        else {
            return extractions
        }
        return [merged(first, second)]
    }

    private static func isFilterReady(_ extraction: PasteImportExtraction) -> Bool {
        extraction.bookingType != nil && extraction.startAt != nil
    }

    private static func looksLikeFlightFragment(_ extraction: PasteImportExtraction) -> Bool {
        extraction.bookingType == .flight
            || flightNumberKey(extraction.title) != nil
            || boardingPassTitle(extraction.title)
    }

    private static func boardingPassTitle(_ title: String?) -> Bool {
        let tokens = PasteImportTextTokens.tokens(in: title)
        return tokens.contains("boarding") || tokens.contains("bordkarte")
    }

    private static func areComplementary(
        _ left: PasteImportExtraction,
        _ right: PasteImportExtraction
    ) -> Bool {
        if let leftType = left.bookingType, let rightType = right.bookingType, leftType != rightType {
            return false
        }
        let leftHasCode = left.confirmationCode != nil
        let rightHasCode = right.confirmationCode != nil
        let leftHasTravel = left.startAt != nil || hasRoute(left)
        let rightHasTravel = right.startAt != nil || hasRoute(right)
        return leftHasCode != rightHasCode && leftHasTravel != rightHasTravel
    }

    /// Zwei erkannte, unterschiedliche Flugnummern gehören nicht zusammen.
    private static func compatibleFlightNumbers(
        _ left: PasteImportExtraction,
        _ right: PasteImportExtraction
    ) -> Bool {
        guard let leftKey = flightNumberKey(left.title),
              let rightKey = flightNumberKey(right.title)
        else {
            return true
        }
        return leftKey == rightKey
    }

    private static func hasRoute(_ extraction: PasteImportExtraction) -> Bool {
        extraction.locationFrom != nil || extraction.locationTo != nil
    }

    private static func merged(
        _ left: PasteImportExtraction,
        _ right: PasteImportExtraction
    ) -> PasteImportExtraction {
        var result = left
        result.mergingMissingFields(from: right)
        result.bookingType = result.bookingType ?? flightHint(left) ?? flightHint(right)
        result.title = preferFlightTitle(left.title, right.title)
        return result
    }

    private static func preferFlightTitle(_ left: String?, _ right: String?) -> String? {
        if flightNumberKey(left) != nil { return left }
        if flightNumberKey(right) != nil { return right }
        return left ?? right
    }

    private static func flightHint(_ extraction: PasteImportExtraction) -> BookingType? {
        flightNumberKey(extraction.title) != nil ? .flight : nil
    }

    /// Normalisierte Flugnummer (`"ua1449"`) oder `nil`, wenn der Titel keine ist.
    private static func flightNumberKey(_ title: String?) -> String? {
        guard let title = NonEmpty.string(title) else { return nil }
        let folded = title.uppercased().filter { $0.isLetter || $0.isNumber || $0.isWhitespace }
        let parts = folded.split(whereSeparator: \.isWhitespace)
        guard parts.count == 2,
              let airline = parts.first,
              let number = parts.last,
              (2...3).contains(airline.count),
              airline.allSatisfy(\.isLetter),
              (1...4).contains(number.count),
              number.allSatisfy(\.isNumber)
        else {
            return nil
        }
        return PasteImportTextTokens.normalize("\(airline)\(number)")
    }
}
