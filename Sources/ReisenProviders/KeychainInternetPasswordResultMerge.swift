import Foundation
import Security

internal enum KeychainInternetPasswordResultMerge {
    static func appendUnique(
        results: [[CFString: Any]],
        into collected: inout [[CFString: Any]],
        seenKeys: inout Set<String>
    ) {
        for attrs in results {
            guard let username = attrs[kSecAttrAccount] as? String,
                  let server = attrs[kSecAttrServer] as? String else { continue }
            let key = "\(server)\u{1f}\(username)"
            if seenKeys.insert(key).inserted {
                collected.append(attrs)
            }
        }
    }
}
