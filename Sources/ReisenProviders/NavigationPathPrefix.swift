import Foundation

public enum NavigationPathPrefix {
    /// `shorter` ist Prefix von `longer` nur bei Gleichheit oder `shorter/`-Grenze; Root `/` nie.
    public static func isPathPrefix(_ shorter: String, of longer: String) -> Bool {
        if shorter == "/" || longer == "/" { return false }
        return longer == shorter || longer.hasPrefix(shorter + "/")
    }
}
