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
              PasteImportFlightNumber.areCompatible(first.title, second.title)
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
            || PasteImportFlightNumber.isPresent(in: extraction.title)
            || PasteImportBookingText.looksLikeBoardingPassTitle(extraction.title)
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

    private static func hasRoute(_ extraction: PasteImportExtraction) -> Bool {
        extraction.locationFrom != nil || extraction.locationTo != nil
    }

    private static func merged(
        _ left: PasteImportExtraction,
        _ right: PasteImportExtraction
    ) -> PasteImportExtraction {
        var result = left
        result.mergingMissingFields(from: right)
        if result.bookingType == nil,
           PasteImportFlightNumber.isPresent(in: left.title)
            || PasteImportFlightNumber.isPresent(in: right.title)
        {
            result.bookingType = .flight
        }
        result.title = PasteImportFlightNumber.preferredTitle(left.title, right.title)
        return result
    }
}
