import Foundation
import ReisenDomain
import ReisenProviders

/// Cognito-JWT: FLOYT-`user_id` aus `username` oder `cognito:username` (nie `sub`).
enum BilligerMietwagenAccessToken {
    /// Claim, den Cognito statt `username` auf Access-/ID-Tokens setzt.
    private static let cognitoUsernameClaim = "cognito:username"

    static func userID(fromAccessToken jwt: String) -> String? {
        let parts = jwt.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count >= 2 else { return nil }
        var payload = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let pad = payload.count % 4
        if pad != 0 {
            payload.append(String(repeating: "=", count: 4 - pad))
        }
        guard let data = Data(base64Encoded: payload),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return nil
        }
        let username = (object[BilligerMietwagenAuthConstants.jwtUsernameClaim] as? String)
            ?? (object[cognitoUsernameClaim] as? String)
        return NonEmpty.string(username)
    }
}
