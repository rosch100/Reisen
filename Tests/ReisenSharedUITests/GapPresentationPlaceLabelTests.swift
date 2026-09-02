import Testing
import Foundation
import ReisenDomain
import ReisenSharedUI

@Test func gapPresentation_transportTitle_usesCityNotAddress() {
    let day: TimeInterval = 24 * 60 * 60
    let from = Booking(
        provider: .manual,
        bookingType: .hotel,
        startAt: Date(timeIntervalSince1970: 0),
        endAt: Date(timeIntervalSince1970: day),
        locationTo: "Paris",
        locationToAddress: "Rue de Rivoli 1, 75001 Paris, France",
        status: .confirmed
    )
    let to = Booking(
        provider: .manual,
        bookingType: .flight,
        startAt: Date(timeIntervalSince1970: 5 * day),
        endAt: Date(timeIntervalSince1970: 5 * day + 3_600),
        locationFrom: "Berlin",
        locationTo: "FRA",
        status: .confirmed
    )
    let gap = ComputedGap(
        gapStart: from.endAt,
        gapEnd: to.startAt,
        kind: .transport,
        fromBooking: from,
        toBooking: to,
        isTripBoundary: false
    )
    let presentation = GapPresentation.resolve(computed: gap, saved: nil)
    #expect(presentation.displayTitle.contains("Paris"))
    #expect(presentation.displayTitle.contains("Berlin"))
    #expect(!presentation.displayTitle.contains("Rue de Rivoli"))
}

@Test func gapPresentation_transportTitle_omitsRouteWhenOnlyAddressKnown() {
    let day: TimeInterval = 24 * 60 * 60
    let from = Booking(
        provider: .manual,
        bookingType: .hotel,
        startAt: Date(timeIntervalSince1970: 0),
        endAt: Date(timeIntervalSince1970: day),
        locationToAddress: "Rue de Rivoli 1, 75001 Paris, France",
        status: .confirmed
    )
    let to = Booking(
        provider: .manual,
        bookingType: .hotel,
        startAt: Date(timeIntervalSince1970: 5 * day),
        endAt: Date(timeIntervalSince1970: 6 * day),
        locationFrom: "Berlin",
        status: .confirmed
    )
    let gap = ComputedGap(
        gapStart: from.endAt,
        gapEnd: to.startAt,
        kind: .transport,
        fromBooking: from,
        toBooking: to,
        isTripBoundary: false
    )
    let presentation = GapPresentation.resolve(computed: gap, saved: nil)
    #expect(presentation.displayTitle == GapKind.transport.defaultDisplayTitle)
    #expect(!presentation.displayTitle.contains("Rue de Rivoli"))
}
