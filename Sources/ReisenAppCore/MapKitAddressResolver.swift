import Foundation
import MapKit

import ReisenDomain

public struct MapKitAddressResolver: AddressResolving, Sendable {
    public init() {}

    public func resolveAddress(query: String) async throws -> String? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return await Self.bestFormattedAddress(matching: trimmed)
    }

    @MainActor
    private static func bestFormattedAddress(matching query: String) async -> String? {
        let mapItems: [MKMapItem]
        do {
            mapItems = try await MapKitQuery.mapItems(matching: query)
        } catch {
            return nil
        }

        let queryLower = query.lowercased()
        let queryTokens: [String] = query
            .lowercased()
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
            .filter { $0.count > 2 }

        guard let best = mapItems
            .map(AddressCandidate.init)
            .max(by: { $0.score(queryLower: queryLower, queryTokens: queryTokens) < $1.score(queryLower: queryLower, queryTokens: queryTokens) })
        else {
            return nil
        }

        return best.formatted
    }
}

private struct AddressCandidate {
    let nameLower: String
    let combined: String
    let formatted: String?

    func score(queryLower: String, queryTokens: [String]) -> Int {
        var score = 0

        if !queryLower.isEmpty, combined.contains(queryLower) {
            score += 200
        }
        if !queryLower.isEmpty, nameLower.contains(queryLower) {
            score += 300
        }

        for token in queryTokens where !token.isEmpty {
            if combined.contains(token) { score += 20 }
            if nameLower.contains(token) { score += 10 }
        }

        return score
    }
}

private extension AddressCandidate {
    init(_ item: MKMapItem) {
        let fields = MapItemAddressFields(item: item)
        let name = fields.name
        self.nameLower = name?.lowercased() ?? ""
        self.combined = fields.combined.lowercased()
        self.formatted = fields.formatted
    }
}

private struct MapItemAddressFields {
    let name: String?
    let combined: String
    let formatted: String?

    init(item: MKMapItem) {
        let name = item.name?.trimmingCharacters(in: .whitespacesAndNewlines)
        let full = item.addressRepresentations?.fullAddress(includingRegion: true, singleLine: true)
            ?? item.address?.fullAddress
        let city = item.addressRepresentations?.cityName
        let region = item.addressRepresentations?.regionName
        self.name = name?.isEmpty == false ? name : nil
        self.combined = Self.nonEmpty([self.name, city, region, full]).joined(separator: " ")
        self.formatted = Self.formattedAddress(name: self.name, full: full)
    }

    private static func nonEmpty(_ parts: [String?]) -> [String] {
        parts
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private static func formattedAddress(name: String?, full: String?) -> String? {
        let trimmedFull = full?.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasFull = trimmedFull.map { !$0.isEmpty } ?? false
        let hasName = name.map { !$0.isEmpty } ?? false

        switch (hasName, hasFull, name, trimmedFull) {
        case (true, true, let name?, let full?) where full.localizedCaseInsensitiveContains(name):
            return full
        case (true, true, let name?, let full?):
            return "\(name), \(full)"
        case (false, true, _, let full?):
            return full
        case (true, false, let name?, _):
            return name
        default:
            return nil
        }
    }
}
