import Testing
import ReisenDomain

@Test func bookingType_activity_rawValueAndLabel() {
    #expect(BookingType.activity.rawValue == "activity")
    #expect(BookingType.activity.displayLabel == "Erlebnis")
    #expect(BookingType.allCases.contains(.activity))
}
