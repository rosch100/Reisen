import Foundation

extension SwiftDataBookingContentKeys {
    static func baggage(typeRaw: String, sectionID: String?, airlineCode: String?) -> String {
        "\(typeRaw)|\(sectionID ?? "")|\(airlineCode ?? "")"
    }

    static func room(confirmationCode: String?, sortIndex: Int?, category: String?) -> String {
        if let confirmationCode, !confirmationCode.isEmpty {
            return "conf|\(confirmationCode)"
        }
        if let sortIndex {
            return "idx|\(sortIndex)"
        }
        return "cat|\(category ?? "")"
    }
}
