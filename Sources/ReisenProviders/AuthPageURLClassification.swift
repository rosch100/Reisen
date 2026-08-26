import Foundation

public enum AuthPageURLClassification {
    /// Host + Path only — Query/Fragment oft mit SSO-`callback`/`context_ref` auf Login-URLs.
    public static func haystack(for absoluteURL: String) -> String {
        let lowered = absoluteURL.lowercased()
        guard let components = URLComponents(string: absoluteURL) else {
            return lowered
        }
        let host = (components.host ?? "").lowercased()
        let path = components.path.lowercased()
        if host.isEmpty && path.isEmpty {
            return lowered
        }
        return host + path
    }
}
