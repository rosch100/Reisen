import Foundation

public enum AutoGapRole: String, Sendable, Equatable {
    case lodging
    case transport
}

public enum AutoGapIdentity {
    public static func key(from: UUID, to: UUID, role: AutoGapRole) -> String {
        "\(from.uuidString)|\(to.uuidString)|\(role.rawValue)"
    }
}

public struct AutoGapDesired: Equatable, Sendable {
    public var identityKey: String
    public var role: AutoGapRole
    public var bookingType: BookingType
    public var startAt: Date
    public var endAt: Date
    public var locationFrom: String?
    public var locationTo: String?
    public var fromBookingID: UUID
    public var toBookingID: UUID

    public init(
        identityKey: String,
        role: AutoGapRole,
        bookingType: BookingType,
        startAt: Date,
        endAt: Date,
        locationFrom: String? = nil,
        locationTo: String? = nil,
        fromBookingID: UUID,
        toBookingID: UUID
    ) {
        self.identityKey = identityKey
        self.role = role
        self.bookingType = bookingType
        self.startAt = startAt
        self.endAt = endAt
        self.locationFrom = locationFrom
        self.locationTo = locationTo
        self.fromBookingID = fromBookingID
        self.toBookingID = toBookingID
    }
}
