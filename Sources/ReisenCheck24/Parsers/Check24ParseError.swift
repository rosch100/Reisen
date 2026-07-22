import Foundation
import ReisenDomain

public enum Check24ParseError: LocalizedError {
    case activityListNotRecognized
    case noBookingDatesFound
    case noBookingLinkFound
    case noCancellationDeadlineFound

    public var errorDescription: String? {
        switch self {
        case .activityListNotRecognized:
            return "Check24 Aktivitätsseite konnte nicht erkannt werden."
        case .noBookingDatesFound:
            return "Keine Buchungsdaten (Start/Ende) konnten im Snapshot gefunden werden."
        case .noBookingLinkFound:
            return "Keine Buchungslinks konnten im Snapshot gefunden werden."
        case .noCancellationDeadlineFound:
            return "Keine Stornofrist im Snapshot gefunden."
        }
    }
}

