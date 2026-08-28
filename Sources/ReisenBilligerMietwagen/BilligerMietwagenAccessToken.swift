import Foundation
import ReisenDomain
import ReisenProviders

/// Cognito-Access-JWT: Claim `jwtUsernameClaim` ist die FLOYT-`user_id` für Refresh (nicht `sub`).
enum BilligerMietwagenAccessToken {
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
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let username = object[BilligerMietwagenAuthConstants.jwtUsernameClaim] as? String
        else {
            return nil
        }
        return NonEmpty.string(username)
    }
}
