import Foundation

extension HotelBasketJSONScan {
    static func updateStringState(
        ch: Character,
        inString: inout Bool,
        isEscaped: inout Bool
    ) {
        if isEscaped {
            isEscaped = false
        } else if ch == "\\" {
            isEscaped = true
        } else if ch == "\"" {
            inString = false
        }
    }
}
