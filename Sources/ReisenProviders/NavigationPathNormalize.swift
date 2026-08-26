import Foundation

public enum NavigationPathNormalize {
    public static func normalizedPath(_ path: String) -> String {
        if path.count > 1, path.hasSuffix("/") {
            return String(path.dropLast())
        }
        return path.isEmpty ? "/" : path
    }
}
