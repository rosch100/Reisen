import Foundation

public enum NavigationHostMatching {
    public static func hostsMatch(_ a: String, _ b: String) -> Bool {
        let left = a.replacingOccurrences(of: "www.", with: "")
        let right = b.replacingOccurrences(of: "www.", with: "")
        return left == right
            || left.hasSuffix(".\(right)")
            || right.hasSuffix(".\(left)")
    }
}
