import Foundation
import ReisenDomain

extension ActivityListParser {
    /// Vergangene (`ended`) und stornierte Buchungen aus; Start muss ab heute (GMT-Hotel-Anker) liegen.
    /// Hotel-Starts sind zuvor über `parseCatalogDate` bereits Kalendertage.
    func isFutureRelevantBooking(
        statusKey: String,
        startAt: Date,
        now: Date
    ) -> Bool {
        if CatalogListing.shouldDrop(statusKey) {
            return false
        }
        let today = HotelStayDate.calendarDay(fromParsed: now)
        return startAt >= today
    }
}
