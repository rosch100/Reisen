import Testing
import ReisenDomain

@Test func gapKindClassifier_hotelNeighbor_isTransport() {
    #expect(GapKindClassifier.classify(from: .hotel, to: .flight) == .transport)
    #expect(GapKindClassifier.classify(from: .flight, to: .hotel) == .transport)
}

@Test func gapKindClassifier_transportPair_isLodging() {
    #expect(GapKindClassifier.classify(from: .flight, to: .ferry) == .lodging)
    #expect(GapKindClassifier.classify(from: .ferry, to: .flight) == .lodging)
}

@Test func gapKindClassifier_mixedOther_isBoth() {
    #expect(GapKindClassifier.classify(from: .flight, to: .other) == .both)
    #expect(GapKindClassifier.classify(from: .other, to: .other) == .both)
}
