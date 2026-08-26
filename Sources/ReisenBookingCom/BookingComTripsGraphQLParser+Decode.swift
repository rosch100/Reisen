import Foundation

extension BookingComTripsGraphQLParser {
    func graphQLFailure(_ errors: [GraphQLErrorMessage]?) -> BookingComTripsGraphQLParserError? {
        guard let errors, !errors.isEmpty else { return nil }
        let message = errors.compactMap(\.message).filter { !$0.isEmpty }.joined(separator: "; ")
        return .graphQLErrors(message.isEmpty ? nil : message)
    }

    func decodeGraphQL<T: Decodable>(_ json: String) throws -> T {
        guard let data = json.data(using: .utf8) else {
            throw BookingComTripsGraphQLParserError.invalidJSON
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw BookingComTripsGraphQLParserError.invalidJSON
        }
    }
}
