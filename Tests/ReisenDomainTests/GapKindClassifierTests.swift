import Testing
import ReisenDomain

@Test func gapKindClassifier_hotelNeighbor_isTransport() {
    #expect(GapKindClassifier.classify(from: .hotel, to: .flight) == .transport)
    #expect(GapKindClassifier.classify(from: .flight, to: .hotel) == .transport)
}

@Test func gapKindClassifier_activityNeighbor_isTransport() {
    #expect(GapKindClassifier.classify(from: .activity, to: .flight) == .transport)
    #expect(GapKindClassifier.classify(from: .flight, to: .activity) == .transport)
}

@Test func gapKindClassifier_onSitePair_isLodging() {
    #expect(GapKindClassifier.classify(from: .hotel, to: .hotel) == .lodging)
    #expect(GapKindClassifier.classify(from: .activity, to: .activity) == .lodging)
    #expect(GapKindClassifier.classify(from: .hotel, to: .activity) == .lodging)
    #expect(GapKindClassifier.classify(from: .activity, to: .hotel) == .lodging)
}

@Test func gapKindClassifier_transportPair_isLodging() {
    #expect(GapKindClassifier.classify(from: .flight, to: .ferry) == .lodging)
    #expect(GapKindClassifier.classify(from: .ferry, to: .flight) == .lodging)
}

@Test func gapKindClassifier_trainNeighbors() {
    #expect(GapKindClassifier.classify(from: .hotel, to: .train) == .transport)
    #expect(GapKindClassifier.classify(from: .train, to: .hotel) == .transport)
    #expect(GapKindClassifier.classify(from: .flight, to: .train) == .lodging)
    #expect(GapKindClassifier.classify(from: .train, to: .ferry) == .lodging)
    #expect(GapKindClassifier.classify(from: .train, to: .other) == .both)
}

@Test func gapKindClassifier_mixedOther_isBoth() {
    #expect(GapKindClassifier.classify(from: .flight, to: .other) == .both)
    #expect(GapKindClassifier.classify(from: .other, to: .other) == .both)
}

@Test func gapKindClassifier_carRentalNeighbors() {
    // carRental ist kein isTransport und kein On-Site → wie .other.
    #expect(GapKindClassifier.classify(from: .hotel, to: .carRental) == .transport)
    #expect(GapKindClassifier.classify(from: .carRental, to: .hotel) == .transport)
    #expect(GapKindClassifier.classify(from: .flight, to: .carRental) == .both)
    #expect(GapKindClassifier.classify(from: .carRental, to: .flight) == .both)
    #expect(GapKindClassifier.classify(from: .carRental, to: .carRental) == .both)
    #expect(GapKindClassifier.classify(from: .carRental, to: .other) == .both)
}
