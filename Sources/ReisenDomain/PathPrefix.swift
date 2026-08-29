import Foundation

/// Segment-sichere Pfad-Prefix-Prüfung (`root` bzw. `root/…`, nicht `root2`).
public enum PathPrefix {
    public static func isUnder(_ path: String, root: String) -> Bool {
        path == root || path.hasPrefix(root + "/")
    }
}
