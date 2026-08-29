import Foundation
import ReisenDomain

/// Führt zwei komplementäre, jeweils unvollständige **Flug-/Boarding**-Fragmente zusammen.
///
/// Hotel-Code + Flugstrecke aus derselben Quelle werden nicht vermischt — nur wenn mindestens
/// ein Fragment als Flugnummer oder Boarding-Pass erkennbar ist.
public enum PasteImportExtractionCoalescer {
    public static func coalescing(_ extractions: [PasteImportExtraction]) -> [PasteImportExtraction] {
        guard extractions.count == 2,
              let first = extractions.first,
              let second = extractions.last,
              !isFilterReady(first),
              !isFilterReady(second),
              looksLikeFlightFragment(first) && looksLikeFlightFragment(second),
              areComplementary(first, second)
        else {
            return extractions
        }
        return [merged(first, second)]
    }

    private static func isFilterReady(_ extraction: PasteImportExtraction) -> Bool {
        extraction.bookingType != nil && extraction.startAt != nil
    }

    private static func looksLikeFlightFragment(_ extraction: PasteImportExtraction) -> Bool {
        if extraction.bookingType == .flight { return true }
        if looksLikeFlightNumber(extraction.title) { return true }
        return boardingPassTitle(extraction.title)
    }

    private static func boardingPassTitle(_ title: String?) -> Bool {
        guard let title = NonEmpty.string(title) else { return false }
        let key = title.lowercased().filter(\.isLetter)
        return key.contains("boardingpass") || key.contains("boarding") || key.contains("bordkarte")
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
        result.bookingType = left.bookingType ?? right.bookingType ?? flightHint(left) ?? flightHint(right)
        result.startAt = left.startAt ?? right.startAt
        result.endAt = left.endAt ?? right.endAt
        result.title = preferFlightTitle(left.title, right.title)
        result.confirmationCode = left.confirmationCode ?? right.confirmationCode
        result.externalUrl = left.externalUrl ?? right.externalUrl
        result.locationFrom = left.locationFrom ?? right.locationFrom
        result.locationTo = left.locationTo ?? right.locationTo
        result.locationFromAddress = left.locationFromAddress ?? right.locationFromAddress
        result.locationToAddress = left.locationToAddress ?? right.locationToAddress
        result.operatorName = left.operatorName ?? right.operatorName
        result.status = left.status ?? right.status
        result.hotelCheckInMinutes = left.hotelCheckInMinutes ?? right.hotelCheckInMinutes
        result.hotelCheckOutMinutes = left.hotelCheckOutMinutes ?? right.hotelCheckOutMinutes
        result.hotelOffsetSeconds = left.hotelOffsetSeconds ?? right.hotelOffsetSeconds
        result.flightDepartureOffsetSeconds =
            left.flightDepartureOffsetSeconds ?? right.flightDepartureOffsetSeconds
        result.flightArrivalOffsetSeconds =
            left.flightArrivalOffsetSeconds ?? right.flightArrivalOffsetSeconds
        if result.passengers.isEmpty { result.passengers = right.passengers }
        if result.guestHints.isEmpty { result.guestHints = right.guestHints }
        result.rateDetails = left.rateDetails ?? right.rateDetails
        if result.deadlines.isEmpty { result.deadlines = right.deadlines }
        return result
    }

    private static func preferFlightTitle(_ left: String?, _ right: String?) -> String? {
        if looksLikeFlightNumber(left) { return left }
        if looksLikeFlightNumber(right) { return right }
        return left ?? right
    }

    private static func flightHint(_ extraction: PasteImportExtraction) -> BookingType? {
        looksLikeFlightNumber(extraction.title) ? .flight : nil
    }

    private static func looksLikeFlightNumber(_ title: String?) -> Bool {
        guard let title = NonEmpty.string(title) else { return false }
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
            return false
        }
        return true
    }
}
