import Foundation
import ReisenDomain

/// Erkennung einer Flugnummer im Titel (`UA 1449` → Key `ua1449`).
enum PasteImportFlightNumber {
    /// Normalisierte Flugnummer oder `nil`, wenn der Titel keine ist.
    static func key(in title: String?) -> String? {
        guard let title = NonEmpty.string(title) else { return nil }
        let folded = title.uppercased().filter { $0.isLetter || $0.isNumber || $0.isWhitespace }
        let parts = folded.split(whereSeparator: \.isWhitespace)
        guard parts.count == 2,
              let airline = parts.first,
              let number = parts.last,
              (2...3).contains(airline.count),
              airline.allSatisfy(\.isLetter),
              (1...4).contains(number.count),
              number.allSatisfy(\.isNumber)
        else {
            return nil
        }
        return PasteImportTextTokens.normalize("\(airline)\(number)")
    }
}
