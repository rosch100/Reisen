import Foundation

extension OpodoTripCancellationGraphQLParser {
    private static let notLoggedInErrorCode = "USER_NOT_LOGGED_IN"

    func decodeTrip(from json: String) throws -> OpodoCancellationTripDTO? {
        let envelope = try OpodoGraphQLRequest.decode(
            OpodoTripCancellationEnvelope.self,
            from: json,
            invalid: OpodoTripCancellationGraphQLParserError.invalidJSON
        )
        try throwIfSessionLost(envelope.errors)
        try throwIfGraphQLFailed(envelope.errors)
        return envelope.data?.getTrip?.trip
    }

    private func throwIfSessionLost(_ errors: [OpodoGraphQLError]?) throws {
        guard let errors, errors.contains(where: Self.isNotLoggedIn) else { return }
        throw OpodoTripCancellationGraphQLParserError.notLoggedIn
    }

    private func throwIfGraphQLFailed(_ errors: [OpodoGraphQLError]?) throws {
        guard let errors, !errors.isEmpty else { return }
        let message = errors.compactMap(\.message).filter { !$0.isEmpty }.joined(separator: "; ")
        throw OpodoTripCancellationGraphQLParserError.graphQLErrors(message.isEmpty ? nil : message)
    }

    private static func isNotLoggedIn(_ error: OpodoGraphQLError) -> Bool {
        error.extensions?.errorCode == notLoggedInErrorCode
    }
}
