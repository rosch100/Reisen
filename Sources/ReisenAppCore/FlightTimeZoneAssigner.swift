import Foundation
import CoreLocation

import ReisenDomain
import ReisenData

@MainActor
public final class FlightTimeZoneAssigner {
    public enum ResolveError: Error {
        case missingIATACode
        case noTimeZoneFound
    }

    private let bookingRepository: SwiftDataBookingRepository
    private let geocoder = CLGeocoder()
    private var cachedTimeZoneByIata: [String: TimeZone] = [:]

    public init(bookingRepository: SwiftDataBookingRepository) {
        self.bookingRepository = bookingRepository
    }

    public func assignMissingOffsets() async throws {
        let bookings = try bookingRepository.fetchAll().filter {
            ($0.bookingType == .flight || $0.bookingType == .ferry)
                && ($0.flightDepartureOffsetSeconds == nil || $0.flightArrivalOffsetSeconds == nil)
        }

        for booking in bookings {
            do {
                var updated = booking
                try await assignOffsets(into: &updated)
                try bookingRepository.upsert(updated)
            } catch ResolveError.missingIATACode {
                continue
            } catch ResolveError.noTimeZoneFound {
                continue
            } catch {
                // Transient geocoding/network failure: skip this booking, keep the batch.
                continue
            }
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
        let placemarks = try await geocode(query: "\(iata) airport")
        guard let tz = placemarks.first?.timeZone else { throw ResolveError.noTimeZoneFound }
        cachedTimeZoneByIata[iata] = tz
        return tz
    }

    private func geocode(query: String) async throws -> [CLPlacemark] {
        try await withCheckedThrowingContinuation { continuation in
            geocoder.geocodeAddressString(query) { placemarks, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let placemarks, !placemarks.isEmpty else {
                    continuation.resume(throwing: ResolveError.noTimeZoneFound)
                    return
                }
                continuation.resume(returning: placemarks)
            }
        }
    }

    private func offsetSeconds(forWallClockInstant wallClockInstant: Date, in timeZone: TimeZone) -> Int {
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
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

