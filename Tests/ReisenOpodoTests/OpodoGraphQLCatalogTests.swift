import Testing
import Foundation
import ReisenOpodo
import ReisenDomain

@Test("OpodoGraphQLCatalog nutzt GraphQL und ignoriert HTML")
func opodoCatalogPrefersNonEmptyGraphQL() throws {
    let graphQL = OpodoGraphQLCatalog(bookings: [try sampleDraft(type: .flight)], rawTripCount: 1)
    let catalog = graphQL.resolved(htmlFallback: [try sampleDraft(type: .hotel)])
    #expect(catalog.bookings.count == 1)
    #expect(catalog.bookings[0].bookingType == .flight)
    #expect(graphQL.needsHTMLFallback == false)
}

@Test("OpodoGraphQLCatalog fällt nur bei leerer GraphQL-Liste auf HTML zurück")
func opodoCatalogHTMLFallbackOnlyWhenGraphQLEmpty() throws {
    let empty = OpodoGraphQLCatalog(bookings: [], rawTripCount: 0)
    #expect(empty.needsHTMLFallback == true)
    let catalog = empty.resolved(htmlFallback: [try sampleDraft(type: .hotel)])
    #expect(catalog.bookings.count == 1)
    #expect(catalog.bookings[0].bookingType == .hotel)
}

@Test("OpodoGraphQLCatalog scrapt HTML nicht wenn GraphQL nur Upsell-Rows hatte")
func opodoCatalogSkipsHTMLWhenGraphQLHadIgnoredRows() throws {
    let upsellOnly = OpodoGraphQLCatalog(bookings: [], rawTripCount: 3)
    #expect(upsellOnly.needsHTMLFallback == false)
    let catalog = upsellOnly.resolved(htmlFallback: [try sampleDraft(type: .hotel)])
    #expect(catalog.bookings.isEmpty)
}

private func sampleDraft(type: BookingType) throws -> ProviderBookingDraft {
    let start = Date(timeIntervalSince1970: 1_788_000_000)
    let end = Date(timeIntervalSince1970: 1_788_086_400)
    let times = TemporalFact.pair(bookingType: type, start: start, end: end)
    return try #require(
        DraftAssembler.draft(
            from: ProviderBookingFacts(
                provider: .opodo,
                bookingType: type,
                start: times.start,
                end: times.end,
                title: type == .flight ? "Flug" : "Hotel",
                externalUrl: OpodoWeb.tripDetailsURL(token: "FAKE")
            )
        )
    )
}
