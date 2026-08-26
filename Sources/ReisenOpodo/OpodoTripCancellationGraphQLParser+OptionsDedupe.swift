import Foundation
import ReisenDomain

extension OpodoTripCancellationGraphQLParser {
    func dedupeDeadlines(_ deadlines: [CancellationDeadline]) -> [CancellationDeadline] {
        var byKey: [String: CancellationDeadline] = [:]
        for deadline in deadlines {
            let feeKey = deadline.cancellationFeeAmount.map { String($0) } ?? ""
            let key = "\(Int(deadline.deadlineAt.timeIntervalSince1970))|\(deadline.isFreeCancellation)|\(feeKey)"
            byKey[key] = deadline
        }
        return Array(byKey.values)
    }
}
