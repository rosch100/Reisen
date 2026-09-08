import Foundation
import ReisenData

/// Persistenz-Hilfen für Trip-Editor-Felder (SharedUI SSOT, testbar ohne View).
public enum TripEditorPersistedFields {
    public static func optionalStored(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    public static func apply(
        title: String,
        startDate: Date,
        endDate: Date,
        destinationRaw: String,
        notesRaw: String,
        to trip: SDTrip
    ) {
        trip.title = title
        trip.startDate = startDate
        trip.endDate = endDate
        trip.destination = optionalStored(destinationRaw)
        trip.notes = optionalStored(notesRaw)
    }
}
