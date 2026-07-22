import Foundation

public struct CancellationDeadline: Identifiable, Equatable, Sendable {
    public var id: UUID
    public var deadlineAt: Date
    public var policyText: String?
    public var isStrict: Bool
    public var isFreeCancellation: Bool
    public var hotelOffsetSeconds: Int?
    public var cancellationFeeAmount: Double?
    public var bookingID: UUID?

    public init(
        id: UUID = UUID(),
        deadlineAt: Date,
        policyText: String? = nil,
        isStrict: Bool = true,
        isFreeCancellation: Bool = false,
        hotelOffsetSeconds: Int? = nil,
        cancellationFeeAmount: Double? = nil,
        bookingID: UUID? = nil
    ) {
        self.id = id
        self.deadlineAt = deadlineAt
        self.policyText = policyText
        self.isStrict = isStrict
        self.isFreeCancellation = isFreeCancellation
        self.hotelOffsetSeconds = hotelOffsetSeconds
        self.cancellationFeeAmount = cancellationFeeAmount
        self.bookingID = bookingID
    }
}
