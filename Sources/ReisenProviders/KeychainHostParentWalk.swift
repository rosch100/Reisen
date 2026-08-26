import Foundation

public enum KeychainHostParentWalk {
    /// Parent-Domains von Host abwärts (inkl. Host selbst).
    public static func walk(from host: String) -> [String] {
        var result: [String] = []
        var current = host
        while true {
            if !result.contains(current) {
                result.append(current)
            }
            let parts = current.split(separator: ".").map(String.init)
            guard parts.count > 2 else { break }
            current = parts.dropFirst().joined(separator: ".")
        }
        return result
    }
}
