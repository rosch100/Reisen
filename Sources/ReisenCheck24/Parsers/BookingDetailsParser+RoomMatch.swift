import Foundation

extension BookingDetailsParser {
    func roomMatchParts(
        match: NSTextCheckingResult,
        html: String
    ) -> (count: Int, category: String?)? {
        guard match.numberOfRanges == 3 else { return nil }
        let countRange = match.range(at: 1)
        let categoryRange = match.range(at: 2)
        guard countRange.location != NSNotFound, categoryRange.location != NSNotFound else { return nil }
        let countText = (html as NSString).substring(with: countRange)
        let category = (html as NSString).substring(with: categoryRange)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let count = Int(countText), count > 0 else { return nil }
        return (count, category.isEmpty ? nil : category)
    }
}
