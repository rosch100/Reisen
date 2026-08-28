import Foundation

extension OpodoTripCancellationGraphQLParser {
    func decodeTrip(from json: String) throws -> OpodoCancellationTripDTO? {
        let envelope = try OpodoGraphQLRequest.decode(
            OpodoTripCancellationEnvelope.self,
            from: json,
            invalid: OpodoTripCancellationGraphQLParserError.invalidJSON
        )
        return envelope.data?.getTrip?.trip
    }
}
