import Foundation
import Testing
import ReisenDomain
import ReisenSharedUI

@Test func tripCreateBookingAssignment_inWindowAssignsToTrip() {
    let tripStart = HotelStayDate.dateOnly(year: 2024, month: 6, day: 1)
    let tripEnd = HotelStayDate.dateOnly(year: 2024, month: 6, day: 10)
    let draftStart = HotelStayDate.localPickerDate(fromStored: HotelStayDate.dateOnly(year: 2024, month: 6, day: 3))
    let draftEnd = HotelStayDate.localPickerDate(fromStored: HotelStayDate.dateOnly(year: 2024, month: 6, day: 5))

    let plan = TripCreateBookingAssignment.plan(
        bookingType: .hotel,
        draftStartAt: draftStart,
        draftEndAt: draftEnd,
        tripStart: tripStart,
        tripEnd: tripEnd
    )
    #expect(plan == .assignToTrip)
}

@Test func tripCreateBookingAssignment_outsideWindowAsksExpand() {
    let tripStart = HotelStayDate.dateOnly(year: 2024, month: 6, day: 1)
    let tripEnd = HotelStayDate.dateOnly(year: 2024, month: 6, day: 10)
    let draftStart = HotelStayDate.localPickerDate(fromStored: HotelStayDate.dateOnly(year: 2024, month: 6, day: 8))
    let draftEnd = HotelStayDate.localPickerDate(fromStored: HotelStayDate.dateOnly(year: 2024, month: 6, day: 15))

    let plan = TripCreateBookingAssignment.plan(
        bookingType: .hotel,
        draftStartAt: draftStart,
        draftEndAt: draftEnd,
        tripStart: tripStart,
        tripEnd: tripEnd
    )
    guard case .askExpand(let proposal) = plan else {
        Issue.record("expected askExpand, got \(plan)")
        return
    }
    #expect(proposal.start == tripStart)
    #expect(proposal.end == HotelStayDate.dateOnly(year: 2024, month: 6, day: 15))
}
