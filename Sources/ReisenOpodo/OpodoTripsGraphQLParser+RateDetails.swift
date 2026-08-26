import Foundation
import ReisenDomain

extension OpodoTripsGraphQLParser {
    func rateDetails(from price: OpodoGraphQLMoney?) -> BookingRateDetails? {
        guard let price else { return nil }
        return BookingRateDetails(
            totalPriceAmount: price.amount,
            totalPriceCurrency: price.currency
        )
    }
}
