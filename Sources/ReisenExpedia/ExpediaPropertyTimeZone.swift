import Foundation
import ReisenProviders

enum ExpediaPropertyTimeZone {
    enum ResolveError: Error, Equatable {
        case emptyAddress
        case noTimeZoneFound
    }

    /// Resolves property-local wall-clock TZ via MapKit SSOT (`MapKitQuery` in ReisenProviders).
    @MainActor
    static func resolve(address: String) async throws -> TimeZone {
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ResolveError.emptyAddress }
        let items = try await MapKitQuery.geocodedMapItems(addressString: trimmed)
        guard let timeZone = items.compactMap(\.timeZone).first else {
            throw ResolveError.noTimeZoneFound
        }
        return timeZone
    }
}
