import Testing
import ReisenDomain

@Test func bookingType_activity_rawValueAndLabel() {
    #expect(BookingType.activity.rawValue == "activity")
    #expect(BookingType.activity.displayLabel == "Erlebnis")
    #expect(BookingType.allCases.contains(.activity))
}

@Test func gapKindClassifier_activityNeighbor_isBoth() {
    #expect(GapKindClassifier.classify(from: .flight, to: .activity) == .both)
    #expect(GapKindClassifier.classify(from: .activity, to: .hotel) == .transport)
    #expect(GapKindClassifier.classify(from: .activity, to: .activity) == .both)
}
