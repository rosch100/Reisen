import Foundation

public enum NavigationPathTailComponent {
    public static func lastSignificantComponent(_ path: String) -> String? {
        let parts = path.split(separator: "/").map(String.init).filter { !$0.isEmpty }
        guard let last = parts.last, last.count >= 8 else { return nil }
        return last
    }
}
