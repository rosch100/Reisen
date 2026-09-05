import Foundation
import MapKit

import ReisenDomain
import ReisenData
import ReisenDiagnostics

@MainActor
public final class FlightTimeZoneAssigner {
    public enum ResolveError: Error {
        case missingIATACode
        case noTimeZoneFound
    }

    private let bookingRepository: SwiftDataBookingRepository
    private var cachedTimeZoneByIata: [String: TimeZone] = [:]

    public init(bookingRepository: SwiftDataBookingRepository) {
        self.bookingRepository = bookingRepository
    }

    public func assignMissingOffsets() async throws {
        let bookings = try bookingRepository.fetchAll().filter {
            $0.bookingType.supportsFlightOffsetAutofill
                && ($0.flightDepartureOffsetSeconds == nil || $0.flightArrivalOffsetSeconds == nil)
        }

        var skippedMissingIATA = 0
        var skippedNoTimeZone = 0
        var skippedTransient = 0

        for booking in bookings {
            do {
                var updated = booking
                try await assignOffsets(into: &updated)
                try bookingRepository.upsert(updated)
            } catch let error as CancellationError {
                throw error
            } catch ResolveError.missingIATACode {
                skippedMissingIATA += 1
                continue
            } catch ResolveError.noTimeZoneFound {
                skippedNoTimeZone += 1
                continue
            } catch {
                // Persist/repository failures must not be swallowed.
                if Self.isLikelyTransientResolveFailure(error) {
                    skippedTransient += 1
                    continue
                }
                throw error
            }
        }

        if skippedMissingIATA + skippedNoTimeZone + skippedTransient > 0 {
            await recordSkipSummary(
                missingIATA: skippedMissingIATA,
                noTimeZone: skippedNoTimeZone,
                transient: skippedTransient
            )
        }
        try bookingRepository.save()
    }

    private func assignOffsets(into booking: inout Booking) async throws {
        let departureIata = extractIata(from: booking.locationFrom)
        let arrivalIata = extractIata(from: booking.locationTo)
        guard let departureIata, let arrivalIata else {
            throw ResolveError.missingIATACode
        }

        if booking.flightDepartureOffsetSeconds == nil {
            let departureTZ = try await resolveTimeZone(for: departureIata)
            booking.flightDepartureOffsetSeconds = offsetSeconds(
                forWallClockInstant: booking.startAt,
                in: departureTZ
            )
        }
        if booking.flightArrivalOffsetSeconds == nil {
            let arrivalTZ = try await resolveTimeZone(for: arrivalIata)
            booking.flightArrivalOffsetSeconds = offsetSeconds(
                forWallClockInstant: booking.endAt,
                in: arrivalTZ
            )
        }
    }

    private func extractIata(from text: String?) -> String? {
        guard let text else { return nil }
        let upper = text.uppercased()
        let pattern = #"\b([A-Z]{3})\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        let ns = upper as NSString
        let range = NSRange(location: 0, length: ns.length)
        guard let match = regex.firstMatch(in: upper, options: [], range: range),
              match.numberOfRanges >= 2 else { return nil }
        let code = ns.substring(with: match.range(at: 1))
        return code.isEmpty ? nil : code
    }

    private func resolveTimeZone(for iata: String) async throws -> TimeZone {
        if let cached = cachedTimeZoneByIata[iata] { return cached }
        let mapItems = try await geocode(query: "\(iata) airport")
        guard let tz = mapItems.compactMap(\.timeZone).first else { throw ResolveError.noTimeZoneFound }
        cachedTimeZoneByIata[iata] = tz
        return tz
    }

    private func geocode(query: String) async throws -> [MKMapItem] {
        let items = try await MapKitQuery.geocodedMapItems(addressString: query)
        guard !items.isEmpty else { throw ResolveError.noTimeZoneFound }
        return items
    }

    private func offsetSeconds(forWallClockInstant wallClockInstant: Date, in timeZone: TimeZone) -> Int {
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = HotelStayDate.timeZone
        let components = utcCalendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: wallClockInstant
        )
        var tzCalendar = utcCalendar
        tzCalendar.timeZone = timeZone
        guard let localDate = tzCalendar.date(from: components) else {
            return timeZone.secondsFromGMT(for: wallClockInstant)
        }
        return timeZone.secondsFromGMT(for: localDate)
    }

    /// Exposed for unit tests (`@testable`); production callers use the assign loop.
    static func isLikelyTransientResolveFailure(_ error: Error) -> Bool {
        let ns = error as NSError
        if ns.domain == NSURLErrorDomain { return true }
        // Geocoding/search flakiness must not abort the whole assign batch.
        if ns.domain == MKErrorDomain { return true }
        return false
    }

    private func recordSkipSummary(missingIATA: Int, noTimeZone: Int, transient: Int) async {
        await DiagnosticLogger.shared.record(
            DiagnosticEvent(
                context: DiagnosticContext(
                    runID: UUID(),
                    providerID: .manual,
                    operation: "flight_timezone_assign"
                ),
                component: "FlightTimeZoneAssigner",
                phase: "assign",
                event: "flight_offset_skip_summary",
                result: .skipped,
                reason: "missing_iata_\(missingIATA)_no_tz_\(noTimeZone)_transient_\(transient)",
                visibility: .publicDiagnostic
            )
        )
    }
}

@MainActor
public final class TimeNormalizationRepair {
    private let bookingRepository: SwiftDataBookingRepository
    private let normalizer = BookingTimeNormalizer()

    public init(bookingRepository: SwiftDataBookingRepository) {
        self.bookingRepository = bookingRepository
    }

    public func repairIfNeeded() throws {
        let bookings = try bookingRepository.fetchAll()
        var didChange = false
        for booking in bookings {
            // Hotels: immer auf reine Datumsanker kanonisieren (auch nach alter Hotel-Mitternacht-Normierung).
            // Andere Typen: nur wenn noch nicht normalisiert.
            if booking.bookingType != .hotel, booking.timesNormalized == true {
                continue
            }
            let updated = normalizer.normalizePendingIfPossible(booking)
            if updated.startAt != booking.startAt
                || updated.endAt != booking.endAt
                || updated.timesNormalized != booking.timesNormalized
                || updated.timesSourceFingerprint != booking.timesSourceFingerprint
                || updated.cancellationDeadlines != booking.cancellationDeadlines {
                try bookingRepository.upsert(updated)
                didChange = true
            }
        }
        if didChange {
            try bookingRepository.save()
        }
    }
}
