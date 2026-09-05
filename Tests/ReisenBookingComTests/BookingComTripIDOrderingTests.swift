import Testing
@testable import ReisenBookingCom

struct BookingComTripIDOrderingTests {
    @Test("mergePreferredTripIDs behält preferred-Reihenfolge nur für aktive GetTrips-IDs")
    func mergeKeepsPreferredOrderForActiveIntersection() {
        let preferred = ["canceled-html", "active-a", "active-b"]
        let active = ["active-b", "active-c", "active-a"]
        let merged = BookingComTripIDOrdering.mergePreferredTripIDs(
            preferred,
            withActiveGetTrips: active
        )
        #expect(merged == ["active-a", "active-b", "active-c"])
    }

    @Test("mergePreferredTripIDs droppt preferred-IDs die GetTrips weggelassen hat")
    func mergeDropsCanceledPreferredIDs() {
        let preferred = ["111111", "222222", "333333"]
        let active = ["222222", "444444"]
        let merged = BookingComTripIDOrdering.mergePreferredTripIDs(
            preferred,
            withActiveGetTrips: active
        )
        #expect(merged == ["222222", "444444"])
        #expect(!merged.contains("111111"))
        #expect(!merged.contains("333333"))
    }

    @Test("mergePreferredTripIDs dedupliziert preferred und hängt ungesehene GetTrips an")
    func mergeDedupesPreferredThenAppendsRest() {
        let preferred = ["a", "b", "a"]
        let active = ["a", "b", "c"]
        let merged = BookingComTripIDOrdering.mergePreferredTripIDs(
            preferred,
            withActiveGetTrips: active
        )
        #expect(merged == ["a", "b", "c"])
    }

    @Test("mergePreferredTripIDs mit leerem preferred liefert GetTrips-Reihenfolge")
    func mergeEmptyPreferredUsesActiveOrder() {
        let merged = BookingComTripIDOrdering.mergePreferredTripIDs(
            [],
            withActiveGetTrips: ["x", "y"]
        )
        #expect(merged == ["x", "y"])
    }
}
