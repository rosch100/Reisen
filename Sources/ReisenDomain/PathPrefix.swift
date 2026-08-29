import Foundation

/// Segment-sichere Pfad-Prefix-Prüfung (`root` bzw. `root/…`, nicht `root2`).
public enum PathPrefix {
    public static func isUnder(_ path: String, root: String) -> Bool {
        if root == "/" {
            return path.hasPrefix("/")
        }
        return path == root || path.hasPrefix(root + "/")
    }
}
