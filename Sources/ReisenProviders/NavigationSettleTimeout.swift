import Foundation

public enum NavigationSettleTimeout {
    public static func error(for url: URL) -> NSError {
        NSError(
            domain: "NavigationAwaiter",
            code: 1,
            userInfo: [
                NSLocalizedDescriptionKey: "Navigation-Timeout für \(url.absoluteString)",
            ]
        )
    }
}
