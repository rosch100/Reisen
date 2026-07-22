import Foundation

/// Passenger type as returned by provider APIs (Opodo: `travellerType`).
public struct BookingPassenger: Equatable, Sendable, Identifiable {
    public var id: UUID
    public var bookingID: UUID?

    /// 1..n as returned by Opodo `numPassenger`.
    public var passengerNumber: Int
    public var travellerType: TravellerType

    /// Display/attributes.
    public var title: String?
    public var givenName: String?
    public var familyName: String?
    public var secondFamilyName: String?
    public var birthDate: Date?

    public var baggageAllowances: [BaggageAllowance]

    public init(
        id: UUID = UUID(),
        bookingID: UUID? = nil,
        passengerNumber: Int,
        travellerType: TravellerType,
        title: String? = nil,
        givenName: String? = nil,
        familyName: String? = nil,
        secondFamilyName: String? = nil,
        birthDate: Date? = nil,
        baggageAllowances: [BaggageAllowance] = []
    ) {
        self.id = id
        self.bookingID = bookingID
        self.passengerNumber = passengerNumber
        self.travellerType = travellerType
        self.title = title
        self.givenName = givenName
        self.familyName = familyName
        self.secondFamilyName = secondFamilyName
        self.birthDate = birthDate
        self.baggageAllowances = baggageAllowances
    }
}

public struct BaggageAllowance: Equatable, Sendable, Identifiable {
    public var id: UUID
    public var passengerID: UUID?

    public var type: BaggageType
    public var pieceCount: Int?
    public var weightKg: Double?

    /// Optional segment reference (may be empty if the provider doesn't provide it reliably).
    public var sectionID: String?
    public var airlineCode: String?

    /// Optional human context.
    public var fromLabel: String?
    public var toLabel: String?

    public init(
        id: UUID = UUID(),
        passengerID: UUID? = nil,
        type: BaggageType,
        pieceCount: Int? = nil,
        weightKg: Double? = nil,
        sectionID: String? = nil,
        airlineCode: String? = nil,
        fromLabel: String? = nil,
        toLabel: String? = nil
    ) {
        self.id = id
        self.passengerID = passengerID
        self.type = type
        self.pieceCount = pieceCount
        self.weightKg = weightKg
        self.sectionID = sectionID
        self.airlineCode = airlineCode
        self.fromLabel = fromLabel
        self.toLabel = toLabel
    }
}

