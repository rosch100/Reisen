import MapKit

public enum MapKitQuery {
    @MainActor
    public static func mapItems(matching query: String) async throws -> [MKMapItem] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        let search = MKLocalSearch(request: request)
        let response = try await search.start()
        return response.mapItems
    }

    @MainActor
    public static func geocodedMapItems(addressString: String) async throws -> [MKMapItem] {
        guard let request = MKGeocodingRequest(addressString: addressString) else {
            return []
        }
        return try await request.mapItems
    }
}
