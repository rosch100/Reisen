import Foundation
import SwiftData

@Model
public final class SDBaggageAllowance {
    public var id: UUID = UUID()
    public var passenger: SDBookingPassenger?

    public var baggageTypeRaw: String = ""
    public var pieceCount: Int?
    public var weightKg: Double?

    public var sectionID: String?
    public var airlineCode: String?
    public var fromLabel: String?
    public var toLabel: String?

    public init(
        id: UUID = UUID(),
        passenger: SDBookingPassenger? = nil,
        baggageTypeRaw: String,
        pieceCount: Int? = nil,
        weightKg: Double? = nil,
        sectionID: String? = nil,
        airlineCode: String? = nil,
        fromLabel: String? = nil,
        toLabel: String? = nil
    ) {
        self.id = id
        self.passenger = passenger
        self.baggageTypeRaw = baggageTypeRaw
        self.pieceCount = pieceCount
        self.weightKg = weightKg
        self.sectionID = sectionID
        self.airlineCode = airlineCode
        self.fromLabel = fromLabel
        self.toLabel = toLabel
    }
}
