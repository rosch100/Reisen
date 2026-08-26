import Foundation
import SwiftData

@Model
public final class SDBookingPassenger {
    public var id: UUID = UUID()
    public var booking: SDBooking?
    public var passengerID: UUID?
    public var passengerNumber: Int = 0
    public var travellerTypeRaw: String?

    public var title: String?
    public var givenName: String?
    public var familyName: String?
    public var secondFamilyName: String?
    public var birthDate: Date?

    @Relationship(deleteRule: .cascade, inverse: \SDBaggageAllowance.passenger)
    public var baggageAllowances: [SDBaggageAllowance]? = []

    public init(
        id: UUID = UUID(),
        booking: SDBooking? = nil,
        passengerID: UUID? = nil,
        passengerNumber: Int,
        travellerTypeRaw: String? = nil,
        title: String? = nil,
        givenName: String? = nil,
        familyName: String? = nil,
        secondFamilyName: String? = nil,
        birthDate: Date? = nil,
        baggageAllowances: [SDBaggageAllowance] = []
    ) {
        self.id = id
        self.booking = booking
        self.passengerID = passengerID
        self.passengerNumber = passengerNumber
        self.travellerTypeRaw = travellerTypeRaw
        self.title = title
        self.givenName = givenName
        self.familyName = familyName
        self.secondFamilyName = secondFamilyName
        self.birthDate = birthDate
        self.baggageAllowances = baggageAllowances
    }
}

public extension SDBookingPassenger {
    var resolvedBaggageAllowances: [SDBaggageAllowance] { baggageAllowances ?? [] }
}
