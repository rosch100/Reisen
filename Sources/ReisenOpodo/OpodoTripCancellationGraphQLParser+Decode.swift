import Foundation

extension OpodoTripCancellationGraphQLParser {
    func decodeTrip(from json: String) throws -> OpodoCancellationTripDTO? {
        guard let data = json.data(using: .utf8) else {
            throw OpodoTripCancellationGraphQLParserError.invalidJSON
        }
        let envelope: OpodoTripCancellationEnvelope
        do {
            envelope = try JSONDecoder().decode(OpodoTripCancellationEnvelope.self, from: data)
        } catch {
            throw OpodoTripCancellationGraphQLParserError.invalidJSON
        }
        return envelope.data?.getTrip?.trip
    }
}
