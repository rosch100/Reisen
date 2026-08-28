import Foundation

/// Suggested trip title from open bookings: `locationTo` as destination label (city or provider text; flights may use airport/IATA); country only when abroad.
public enum TripTitleSuggestion {
    public static func from(
        bookings: [Booking],
        locale: Locale = .current
    ) -> String? {
        guard let booking = earliestBooking(in: bookings) else { return nil }

        let city = NonEmpty.string(booking.locationTo)
        let bookingCountryCode = countryCode(from: booking, locale: locale)
        let deviceCountryCode = locale.region?.identifier.uppercased()

        let foreignCountryName: String? = {
            guard let code = bookingCountryCode else { return nil }
            guard let deviceCountryCode else {
                return localizedCountryName(for: code, locale: locale)
            }
            guard code.uppercased() != deviceCountryCode.uppercased() else { return nil }
            return localizedCountryName(for: code, locale: locale)
        }()

        if let city {
            if let foreignCountryName {
                return "\(city), \(foreignCountryName)"
            }
            return city
        }

        return foreignCountryName
    }

    private static func earliestBooking(in bookings: [Booking]) -> Booking? {
        bookings.min { lhs, rhs in
            if lhs.startAt != rhs.startAt {
                return lhs.startAt < rhs.startAt
            }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    private static func countryCode(from booking: Booking, locale: Locale) -> String? {
        isoCountryCode(fromAddress: booking.locationToAddress, locale: locale)
    }

    private static func isoCountryCode(fromAddress address: String?, locale: Locale) -> String? {
        guard let address = NonEmpty.string(address) else { return nil }
        guard let lastPart = address.split(separator: ",").last.map(String.init) else { return nil }
        let candidate = lastPart.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard candidate.count == 2, candidate.allSatisfy(\.isLetter) else { return nil }
        guard locale.localizedString(forRegionCode: candidate) != nil else { return nil }
        return candidate
    }

    private static func localizedCountryName(for regionCode: String, locale: Locale) -> String? {
        let name = NonEmpty.string(locale.localizedString(forRegionCode: regionCode))
        return name
    }
}
