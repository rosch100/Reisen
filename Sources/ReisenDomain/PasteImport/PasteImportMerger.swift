import Foundation

/// Ergänzt eine bestehende Buchung um Paste-Import-Werte, ohne vorhandene Angaben zu überschreiben.
///
/// Gefüllt wird nur, was leer ist: `nil`, bei Strings zusätzlich „nach Trim leer“, bei Listen „leer“.
/// Identität (`id`, `provider`, `externalUrl`, `lastSyncedAt`, `tripID`) sowie Typ und Zeitraum
/// (`bookingType`, `startAt`, `endAt`) bleiben unverändert — dafür ist der Paste-Import nicht die Quelle.
public enum PasteImportMerger {
    public static func fillingGaps(on booking: Booking, from draft: PasteImportDraft) -> Booking {
        var merged = booking
        fillStrings(&merged, from: draft)
        fillScalars(&merged, from: draft)
        fillCollections(&merged, from: draft)
        return merged
    }

    private static func fillStrings(_ booking: inout Booking, from draft: PasteImportDraft) {
        fillString(&booking, \.title, draft.title)
        fillString(&booking, \.confirmationCode, draft.confirmationCode)
        fillString(&booking, \.locationFrom, draft.locationFrom)
        fillString(&booking, \.locationTo, draft.locationTo)
        fillString(&booking, \.locationFromAddress, draft.locationFromAddress)
        fillString(&booking, \.locationToAddress, draft.locationToAddress)
        fillString(&booking, \.operatorName, draft.operatorName)
    }

    private static func fillScalars(_ booking: inout Booking, from draft: PasteImportDraft) {
        fillNil(&booking, \.hotelCheckInMinutes, draft.hotelCheckInMinutes)
        fillNil(&booking, \.hotelCheckOutMinutes, draft.hotelCheckOutMinutes)
        fillNil(&booking, \.hotelOffsetSeconds, draft.hotelOffsetSeconds)
        fillNil(&booking, \.flightDepartureOffsetSeconds, draft.flightDepartureOffsetSeconds)
        fillNil(&booking, \.flightArrivalOffsetSeconds, draft.flightArrivalOffsetSeconds)
        fillNil(&booking, \.rateDetails, draft.rateDetails)
    }

    private static func fillCollections(_ booking: inout Booking, from draft: PasteImportDraft) {
        fillEmpty(&booking, \.passengers, draft.passengers)
        fillEmpty(&booking, \.guestHints, draft.guestHints)
        fillEmpty(&booking, \.cancellationDeadlines, draft.deadlines)
    }

    /// String-Lücke: Ziel `nil` oder nach Trim leer. Übernommen wird der getrimmte Paste-Wert.
    private static func fillString(
        _ booking: inout Booking,
        _ keyPath: WritableKeyPath<Booking, String?>,
        _ value: String?
    ) {
        guard NonEmpty.string(booking[keyPath: keyPath]) == nil, let value = NonEmpty.string(value) else {
            return
        }
        booking[keyPath: keyPath] = value
    }

    private static func fillNil<Value>(
        _ booking: inout Booking,
        _ keyPath: WritableKeyPath<Booking, Value?>,
        _ value: Value?
    ) {
        guard booking[keyPath: keyPath] == nil, let value else { return }
        booking[keyPath: keyPath] = value
    }

    private static func fillEmpty<Value>(
        _ booking: inout Booking,
        _ keyPath: WritableKeyPath<Booking, [Value]>,
        _ values: [Value]
    ) {
        guard booking[keyPath: keyPath].isEmpty, !values.isEmpty else { return }
        booking[keyPath: keyPath] = values
    }
}
