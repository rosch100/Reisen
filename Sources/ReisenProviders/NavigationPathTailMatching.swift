import Foundation

public enum NavigationPathTailMatching {
    public static func tailsMatch(currentPath: String, targetPath: String) -> Bool {
        guard let targetTail = NavigationPathComponents.lastSignificantComponent(targetPath) else {
            return false
        }
        if let currentTail = NavigationPathComponents.lastSignificantComponent(currentPath),
           currentTail == targetTail {
            return true
        }
        return currentPath.contains(targetTail)
    }
}
