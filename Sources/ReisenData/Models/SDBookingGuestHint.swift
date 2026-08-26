import Foundation
import SwiftData

@Model
public final class SDBookingGuestHint {
    public var id: UUID = UUID()
    public var bookingID: UUID?
    public var categoryRaw: String = "preTravelImportant"
    public var title: String = ""
    public var detail: String = ""
    public var sourceKey: String = ""
    public var providerRaw: String?

    public var booking: SDBooking?

    public init(
        id: UUID = UUID(),
        booking: SDBooking? = nil,
        bookingID: UUID? = nil,
        categoryRaw: String = "preTravelImportant",
        title: String = "",
        detail: String = "",
        sourceKey: String = "",
        providerRaw: String? = nil
    ) {
        self.id = id
        self.booking = booking
        self.bookingID = bookingID
        self.categoryRaw = categoryRaw
        self.title = title
        self.detail = detail
        self.sourceKey = sourceKey
        self.providerRaw = providerRaw
    }
}
