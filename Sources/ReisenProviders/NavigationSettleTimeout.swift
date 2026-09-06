import Foundation

public enum NavigationSettleTimeout {
    public static let errorDomain = "NavigationAwaiter"
    public static let errorCode = 1
    public static let diagnosticReason = "navigation_timeout"

    public static func isTimeout(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == errorDomain && nsError.code == errorCode
    }

    public static func error(for url: URL) -> NSError {
        NSError(
            domain: errorDomain,
            code: errorCode,
            userInfo: [
                NSLocalizedDescriptionKey: "Navigation-Timeout für \(url.absoluteString)",
            ]
        )
    }
}
