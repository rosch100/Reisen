import Foundation
import SwiftData

@Model
public final class SDCancellationDeadline {
    public var id: UUID = UUID()
    public var deadlineAt: Date = Date(timeIntervalSince1970: 0)
    public var policyText: String?
    public var isStrict: Bool = true
    public var isFreeCancellation: Bool = false
    public var hotelOffsetSeconds: Int?
    public var cancellationFeeAmount: Double?

    public var booking: SDBooking?

    public init(
        id: UUID = UUID(),
        deadlineAt: Date,
        policyText: String? = nil,
        isStrict: Bool = true,
        isFreeCancellation: Bool = false,
        hotelOffsetSeconds: Int? = nil,
        cancellationFeeAmount: Double? = nil,
        booking: SDBooking? = nil
    ) {
        self.id = id
        self.deadlineAt = deadlineAt
        self.policyText = policyText
        self.isStrict = isStrict
        self.isFreeCancellation = isFreeCancellation
        self.hotelOffsetSeconds = hotelOffsetSeconds
        self.cancellationFeeAmount = cancellationFeeAmount
        self.booking = booking
    }
}
