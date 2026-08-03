import Foundation
import Testing
import ReisenDomain

@Test func hotelTimeZone_prefersBookingOffset() {
    let tz = HotelTimeZone.resolve(bookingOffsetSeconds: 8 * 3600, deadlineOffsetSeconds: 0)
    #expect(tz.secondsFromGMT() == 8 * 3600)
}

@Test func hotelTimeZone_fallsBackToDeadlineOffset() {
    let tz = HotelTimeZone.resolve(bookingOffsetSeconds: nil, deadlineOffsetSeconds: -5 * 3600)
    #expect(tz.secondsFromGMT() == -5 * 3600)
}

@Test func hotelTimeZone_defaultIsWallClockUTC() {
    let tz = HotelTimeZone.resolve(bookingOffsetSeconds: nil, deadlineOffsetSeconds: nil)
    #expect(tz.secondsFromGMT() == 0)
}

@Test func hotelTimeZone_resolveFromTo_usesFromFirst() {
    let tz = HotelTimeZone.resolve(fromOffsetSeconds: 3600, toOffsetSeconds: 7200)
    #expect(tz.secondsFromGMT() == 3600)
}
