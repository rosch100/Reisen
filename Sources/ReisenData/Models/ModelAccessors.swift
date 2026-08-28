import Foundation
import ReisenDomain

public extension SDBooking {
    var bookingType: BookingType {
        BookingType(rawValue: bookingTypeRaw) ?? .other
    }

    var status: BookingStatus {
        BookingStatus(rawValue: statusRaw) ?? .unknown
    }

    var provider: ProviderID {
        ProviderID(rawValue: providerRaw)
    }

    /// Hotel-Wall-Clock-TZ über Domain-SSOT (`HotelTimeZone`).
    var resolvedHotelTimeZone: TimeZone {
        HotelTimeZone.resolve(
            bookingOffsetSeconds: hotelOffsetSeconds,
            deadlineOffsetSeconds: resolvedCancellationDeadlines.compactMap(\.hotelOffsetSeconds).first
        )
    }

    /// Browser-öffentliche URL (ohne manuelle Pseudo-URLs).
    var browserURL: URL? {
        BookingExternalURL.browserURL(from: externalUrl)
    }

    var displayTitle: String {
        title ?? bookingType.defaultDisplayTitle
    }

    var daySpan: BookingDaySpan {
        BookingDaySpan(
            id: id,
            startAt: startAt,
            endAt: endAt,
            placeKey: locationTo ?? locationFrom ?? ""
        )
    }

    var resolvedFlightDepartureTimeZone: TimeZone {
        flightDepartureOffsetSeconds.flatMap { TimeZone(secondsFromGMT: $0) } ?? .current
    }

    var resolvedFlightArrivalTimeZone: TimeZone {
        flightArrivalOffsetSeconds.flatMap { TimeZone(secondsFromGMT: $0) } ?? .current
    }

    /// HIG: nur Vor-/Nachname, keine Titel (MR/MS/Mx).
    var passengerDisplayNames: [String] {
        resolvedPassengers.compactMap { pax -> String? in
            let parts = [pax.givenName, pax.familyName].compactMap { part -> String? in
                guard let part else { return nil }
                let trimmed = part.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : trimmed
            }
            let fullName = parts.joined(separator: " ")
            return fullName.isEmpty ? nil : fullName
        }
    }
}

public extension SDGap {
    var kind: GapKind {
        GapKind(rawValue: kindRaw) ?? .both
    }
}

public extension SDBookingRateDetails {
    var boardType: BookingBoardType {
        guard let boardTypeRaw, let value = BookingBoardType(rawValue: boardTypeRaw) else {
            return .unknown
        }
        return value
    }
}
