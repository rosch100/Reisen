import Testing
import ReisenDomain

@Test func placeKey_nilAndBlank() {
    #expect(PlaceKey.normalize(nil) == nil)
    #expect(PlaceKey.normalize("   ") == nil)
}

@Test func placeKey_trimsAndCasefolds() {
    #expect(PlaceKey.normalize("  Berlin ") == "berlin")
}

@Test func placeKey_prefersIataToken() {
    #expect(PlaceKey.normalize("muc") == "MUC")
    #expect(PlaceKey.normalize("MUC") == "MUC")
}

@Test func placeKey_parentheticalIata() {
    #expect(PlaceKey.normalize("Munich (MUC)") == "MUC")
}
