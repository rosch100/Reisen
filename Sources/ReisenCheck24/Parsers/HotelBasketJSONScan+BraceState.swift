import Foundation

extension HotelBasketJSONScan {
    static func updateBraceAndStringState(
        ch: Character,
        braceDepth: inout Int,
        inString: inout Bool,
        openBraceIndex: String.Index,
        currentIndex: String.Index
    ) -> Bool {
        if ch == "\"" {
            inString = true
            return false
        }

        if ch == "{" {
            braceDepth += 1
            return false
        }

        if ch == "}" {
            braceDepth -= 1
            return braceDepth == 0 && currentIndex >= openBraceIndex
        }

        return false
    }
}
