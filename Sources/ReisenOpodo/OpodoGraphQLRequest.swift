import Foundation

/// SSOT for Opodo GraphQL POST bodies and JSON envelopes.
enum OpodoGraphQLRequest {
    static func body(query: String, operationName: String, variables: [String: Any]) throws -> Data {
        try JSONSerialization.data(
            withJSONObject: [
                "query": query,
                "operationName": operationName,
                "variables": variables,
            ],
            options: []
        )
    }

    static func decode<T: Decodable>(_ type: T.Type, from json: String, invalid: some Error) throws -> T {
        guard let data = json.data(using: .utf8) else { throw invalid }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw invalid
        }
    }
}
