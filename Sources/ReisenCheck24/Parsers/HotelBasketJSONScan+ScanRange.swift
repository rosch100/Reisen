import Foundation

extension HotelBasketJSONScan {
    static func scanTopLevelJSONObjectRange(
        text: String,
        openBraceIndex: String.Index
    ) -> ClosedRange<String.Index>? {
        var i = openBraceIndex
        var braceDepth = 0
        var inString = false
        var isEscaped = false

        while i < text.endIndex {
            let ch = text[i]

            if inString {
                updateStringState(ch: ch, inString: &inString, isEscaped: &isEscaped)
            } else if updateBraceAndStringState(
                ch: ch,
                braceDepth: &braceDepth,
                inString: &inString,
                openBraceIndex: openBraceIndex,
                currentIndex: i
            ) {
                return openBraceIndex...i
            }

            i = text.index(after: i)
        }

        return nil
    }
}
