import Testing
import Foundation
import ReisenDomain

@Test func providerAutoGap_isDistinctFromManual() {
    #expect(ProviderID.autoGap.rawValue == "autoGap")
    #expect(ProviderID.autoGap != .manual)
}

@Test func booking_isRealForGapDetect_excludesAutoAndCancelled() {
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    let auto = Booking(
        provider: .autoGap,
        bookingType: .hotel,
        startAt: now,
        endAt: now.addingTimeInterval(3600),
        autoGapIdentityKey: "a|b|lodging"
    )
    let cancelled = Booking(
        provider: .manual,
        bookingType: .hotel,
        startAt: now,
        endAt: now.addingTimeInterval(3600),
        status: .cancelled
    )
    let real = Booking(
        provider: .manual,
        bookingType: .hotel,
        startAt: now,
        endAt: now.addingTimeInterval(3600),
        status: .confirmed
    )
    #expect(auto.isAutoGap)
    #expect(auto.autoGapIdentityKey == "a|b|lodging")
    #expect(!auto.isRealForGapDetect)
    #expect(!cancelled.isRealForGapDetect)
    #expect(real.isRealForGapDetect)
    #expect(!real.isAutoGap)
}
