import Testing
import ReisenSharedUI

@Test func tripOverviewPresentation_orderFull() {
    let fields = TripOverviewPresentation.visibleFields(
        hasDestination: true,
        hasBookings: true,
        hasNotes: true
    )
    #expect(fields == [
        .title, .destination, .period, .cost, .completeness, .notes
    ])
}

@Test func tripOverviewPresentation_omitsOptional() {
    let fields = TripOverviewPresentation.visibleFields(
        hasDestination: false,
        hasBookings: false,
        hasNotes: false
    )
    #expect(fields == [.title, .period, .cost])
}

@Test func tripOverviewPresentation_completenessRequiresBookings() {
    let fields = TripOverviewPresentation.visibleFields(
        hasDestination: true,
        hasBookings: false,
        hasNotes: true
    )
    #expect(fields == [.title, .destination, .period, .cost, .notes])
}
