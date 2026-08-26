import Foundation

extension ActivityListParser {
    func nonEmptyAddressPart(_ s: String?) -> String? {
        guard let s, !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
