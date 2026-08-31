import Foundation
import ReisenDomain

enum AirbnbScheduledEventsPayment {
    static func parse(rows: [AirbnbScheduledEventRow]) -> BookingRateDetails? {
        let row = rows.first(where: { $0.id == "payment_summary" })
        guard let row, let subtitle = row.subtitle else { return nil }
        return AirbnbMoneyAmount.rateDetails(from: subtitle)
    }
}
