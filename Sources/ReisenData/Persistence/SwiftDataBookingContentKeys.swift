import Foundation

/// Content-identity keys for booking child upsert matching (CloudKit-stable).
enum SwiftDataBookingContentKeys {
    static func deadline(deadlineAt: Date, fee: Double?) -> String {
        let feeKey = fee.map { String(format: "%.4f", $0) } ?? ""
        return "\(Int(deadlineAt.timeIntervalSince1970))|\(feeKey)"
    }
}
