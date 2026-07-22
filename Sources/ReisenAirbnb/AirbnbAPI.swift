import Foundation

/// Airbnb web/API constants (SSOT for persisted-query SHAs + base endpoints).
enum AirbnbAPI {
    static let baseURL = URL(string: "https://www.airbnb.de")!

    static let tripListQuerySHA = "219c3c5c1841a3b2c4fed9329a0708dd384b987515e24c8eda8af1608af69608"
    static let tripDetailsQuerySHA = "2de2346883822f98ab1730df6d608cd65a5ab05f17a72e3c3edfc5b2b39f2056"
    static let reservationMapCardQuerySHA = "61581937e9ee008d401bfe4aea85d552a2e215e4a059f6dd8e48ad8217abe606"

    static let apiKeyHeader = "X-Airbnb-API-Key"
    /// Public web client key captured from the HAR (not a user secret).
    static let apiKeyValue = "d306zoyjsyarp7ifhu67rjxn52tv0t20"

    static let graphqlPlatformHeader = "X-Airbnb-GraphQL-Platform"
    static let graphqlPlatformValue = "web"

    static let graphqlPlatformClientHeader = "X-Airbnb-GraphQL-Platform-Client"
    static let graphqlPlatformClientValue = "minimalist-niobe"

    static let csrfWithoutTokenHeader = "X-CSRF-Without-Token"
    static let csrfWithoutTokenValue = "1"

    static func tripListQueryURL() -> URL {
        URL(string: "/api/v3/TripListQuery/\(tripListQuerySHA)")!.appendingQueryItems(
            [
                "operationName": "TripListQuery",
                "locale": "de",
                "currency": "EUR",
            ],
            variables: "{}",
            extensionsJSON: """
            {"persistedQuery":{"version":1,"sha256Hash":"\(tripListQuerySHA)"}}
            """
        )
    }

    static func tripDetailsQueryURL(relayTripIDBase64: String) -> URL {
        let variablesJSON = """
        {"tripId":"\(relayTripIDBase64)"}
        """
        return URL(string: "/api/v3/TripDetailsQuery/\(tripDetailsQuerySHA)")!.appendingQueryItems(
            [
                "operationName": "TripDetailsQuery",
                "locale": "de",
                "currency": "EUR",
            ],
            variables: variablesJSON,
            extensionsJSON: """
            {"persistedQuery":{"version":1,"sha256Hash":"\(tripDetailsQuerySHA)"}}
            """
        )
    }
}

private extension URL {
    func appendingQueryItems(
        _ items: [String: String],
        variables: String,
        extensionsJSON: String
    ) -> URL {
        var url = URLComponents(url: self, resolvingAgainstBaseURL: true)!
        url.host = AirbnbAPI.baseURL.host
        url.scheme = AirbnbAPI.baseURL.scheme

        url.queryItems = []
        for (k, v) in items {
            url.queryItems?.append(URLQueryItem(name: k, value: v))
        }
        url.queryItems?.append(URLQueryItem(name: "variables", value: variables))
        url.queryItems?.append(URLQueryItem(name: "extensions", value: extensionsJSON))
        return url.url!
    }
}

