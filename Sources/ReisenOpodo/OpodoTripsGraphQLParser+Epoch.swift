import Foundation

extension OpodoTripsGraphQLParser {
    func dateFromEpochMillis(_ raw: Int64?) -> Date? {
        guard let raw else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(raw) / 1000)
    }
}
