import Foundation

public enum AuthPageURLAccountMarker {
    /// `account` soll nicht als Prefix von `accounts` matchen.
    public static func shouldSkipPlural(
        haystack: String,
        range: Range<String.Index>
    ) -> Bool {
        let after = range.upperBound
        return after < haystack.endIndex && haystack[after] == "s"
    }
}
