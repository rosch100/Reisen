import Foundation
import ReisenDomain

extension OpodoActivityListParser {
    func parseDate(_ raw: String) -> Date? {
        HotelStayDate.parse(raw) ?? HotelStayDate.parseGerman(
            raw.replacingOccurrences(of: #"T.*$"#, with: "", options: .regularExpression)
        )
    }
}
