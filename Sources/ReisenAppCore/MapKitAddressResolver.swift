import Foundation
import MapKit

import ReisenDomain

public struct MapKitAddressResolver: AddressResolving, Sendable {
    public init() {}

    public func resolveAddress(query: String) async throws -> String? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = trimmed

        return await withCheckedContinuation { continuation in
            let search = MKLocalSearch(request: request)
            search.start { (response: MKLocalSearch.Response?, error: Error?) in
                if error != nil {
                    continuation.resume(returning: nil)
                    return
                }

                guard let mapItems = response?.mapItems else {
                    continuation.resume(returning: nil)
                    return
                }

                let queryLower = trimmed.lowercased()
                let queryTokens: [String] = trimmed
                    .lowercased()
                    .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
                    .map(String.init)
                    .filter { $0.count > 2 }

                func score(place: MKPlacemark) -> Int {
                    let nameLower = place.name?.lowercased() ?? ""
                    let localityLower = place.locality?.lowercased() ?? ""
                    let adminLower = place.administrativeArea?.lowercased() ?? ""
                    let postalLower = place.postalCode?.lowercased() ?? ""
                    let countryLower = place.country?.lowercased() ?? ""

                    let combined = [nameLower, localityLower, adminLower, postalLower, countryLower]
                        .joined(separator: " ")

                    var score = 0

                    // Strong signal: query is contained in the candidate.
                    if !queryLower.isEmpty, combined.contains(queryLower) {
                        score += 200
                    }
                    if !queryLower.isEmpty, nameLower.contains(queryLower) {
                        score += 300
                    }

                    // Token overlap (hotel names / city names).
                    for token in queryTokens where !token.isEmpty {
                        if combined.contains(token) { score += 20 }
                    }

                    // Mild boost for exact token in name.
                    for token in queryTokens where !token.isEmpty {
                        if nameLower.contains(token) { score += 10 }
                    }

                    return score
                }

                // Pick the most relevant map item (avoids wrong "first match").
                let bestPlacemark: MKPlacemark? = mapItems
                    .map(\.placemark)
                    .max(by: { score(place: $0) < score(place: $1) })

                guard let placemark = bestPlacemark else {
                    continuation.resume(returning: nil)
                    return
                }

                // Build a lightweight, sendable representation immediately.
                let parts: [String?] = [
                    placemark.name,
                    placemark.locality,
                    placemark.administrativeArea,
                    placemark.postalCode,
                    placemark.country
                ]

                let formattedParts = parts
                    .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }

                let formatted = formattedParts.isEmpty ? nil : formattedParts.joined(separator: ", ")
                continuation.resume(returning: formatted)
            }
        }
    }
}

