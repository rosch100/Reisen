import Foundation
import ReisenDomain
import ReisenDiagnostics

enum GetYourGuideJSONDecoder {
    static let shared: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            if let date = ISODateTime.parseInstant(raw) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Ungültiges ISO-8601-Datum: \(raw)"
            )
        }
        return decoder
    }()

    static func decode<T: Decodable>(_ type: T.Type, from data: Data) -> T? {
        do {
            return try shared.decode(type, from: data)
        } catch {
            recordDecodeSkipped(typeName: String(describing: type), error: error)
            return nil
        }
    }

    private static func recordDecodeSkipped(typeName: String, error: Error) {
        Task {
            await DiagnosticLogger.shared.record(
                DiagnosticEvent(
                    context: DiagnosticContext(
                        runID: UUID(),
                        providerID: .getYourGuide,
                        operation: "gyg_json_decode"
                    ),
                    component: "GetYourGuideJSONDecoder",
                    phase: "decode",
                    event: "json_decode_skipped",
                    result: .skipped,
                    reason: "\(typeName):\(String(describing: type(of: error)))",
                    visibility: .publicDiagnostic
                )
            )
        }
    }
}
