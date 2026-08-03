import Foundation

public enum BookingTimeFingerprints {
    public static func hotel(
        rawStartAt: Date,
        rawEndAt: Date,
        hotelOffsetSeconds: Int,
        checkInMinutes: Int,
        checkOutMinutes: Int
    ) -> String {
        "hotel|\(Int(rawStartAt.timeIntervalSince1970))|\(Int(rawEndAt.timeIntervalSince1970))|\(hotelOffsetSeconds)|\(checkInMinutes)|\(checkOutMinutes)"
    }

    public static func flight(
        rawStartAt: Date,
        rawEndAt: Date,
        flightDepartureOffsetSeconds: Int,
        flightArrivalOffsetSeconds: Int,
        locationFrom: String?,
        locationTo: String?
    ) -> String {
        let from = locationFrom ?? ""
        let to = locationTo ?? ""
        return "flight|\(Int(rawStartAt.timeIntervalSince1970))|\(Int(rawEndAt.timeIntervalSince1970))|\(flightDepartureOffsetSeconds)|\(flightArrivalOffsetSeconds)|\(from)|\(to)"
    }
}
