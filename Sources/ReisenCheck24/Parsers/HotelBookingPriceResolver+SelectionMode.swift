import Foundation
import ReisenDomain

extension HotelBookingPriceResolver {
    enum PriceSelectionMode {
        case catalog
        case detailOrderTotal
        case merged
    }

    static func priceSelectionMode(
        booking: ParsedBooking,
        hasLinkedMultiRoomActivities: Bool,
        detailRoomCount: Int?,
        detail: ParsedBookingDetails?
    ) -> PriceSelectionMode {
        // Mehrere Activities = je Zimmer eine Position → Katalogpreis behalten.
        let useCatalogPrice =
            booking.catalogPriceAmount != nil
            && hasLinkedMultiRoomActivities

        // Eine Activity, Detailseite mit mehreren Zimmern → Bestell-Gesamtpreis.
        let useDetailOrderTotal =
            !hasLinkedMultiRoomActivities
            && (detailRoomCount ?? 0) > 1
            && detail?.totalPriceAmount != nil

        if useCatalogPrice { return .catalog }
        if useDetailOrderTotal { return .detailOrderTotal }
        return .merged
    }
}
