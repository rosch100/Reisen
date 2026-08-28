import Testing
import Foundation
import ReisenDomain
@testable import ReisenBookingCom

@Test func bookingComDeepLinkBuilder_hotelAndFlightPrefill() {
    let context = GapContext(
        gapStart: Date(timeIntervalSince1970: 1_800_000_000),
        gapEnd: Date(timeIntervalSince1970: 1_800_086_400),
        kind: .both,
        fromLocationFrom: "FRA",
        fromLocationTo: "MUC",
        toLocationFrom: "PMI",
        toLocationTo: nil
    )
    let result = BookingComDeepLinkBuilder().suggestions(for: context)
    let hotel = result.links.first { $0.category == .hotel }
    let flight = result.links.first { $0.category == .flight }
    #expect(hotel?.url?.absoluteString.contains("ss=MUC") == true)
    #expect(hotel?.url?.absoluteString.contains("checkin=") == true)
    #expect(flight?.url?.absoluteString.contains("MUC.AIRPORT-PMI.AIRPORT") == true)
}

@Test func bookingComDeepLinkBuilder_lodgingOmitsFlightIssues() {
    let context = GapContext(
        gapStart: Date(timeIntervalSince1970: 1_800_000_000),
        gapEnd: Date(timeIntervalSince1970: 1_800_086_400),
        kind: .lodging,
        fromLocationFrom: nil,
        fromLocationTo: "Berlin",
        toLocationFrom: nil,
        toLocationTo: nil
    )
    let result = BookingComDeepLinkBuilder().suggestions(for: context)
    #expect(result.links.allSatisfy { $0.category == .hotel })
    #expect(!result.issues.contains(.missingFromIATA))
}
