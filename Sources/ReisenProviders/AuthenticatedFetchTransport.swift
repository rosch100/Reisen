import Foundation

/// Mappt URLSession-Transportfehler auf typisierte Authenticated-Fetch-Fehler.
public enum AuthenticatedFetchTransport {
    public static func mapURLSessionError(_ error: Error) -> Error {
        if let urlError = error as? URLError, urlError.code == .timedOut {
            return AuthenticatedFetchError.timedOut
        }
        return error
    }
}
