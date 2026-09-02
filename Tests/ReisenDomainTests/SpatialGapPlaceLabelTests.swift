import Testing
import Foundation
import ReisenDomain

private let parisAddress = "Rue de Rivoli 1, 75001 Paris, France"
private let munichAddress = "Musterstraße 1, 80331 München, Deutschland"

@Test func fromEndPlaceLabel_ignoresAddressWhenCityMissing() {
    let hotel = Booking(
        provider: .manual,
        bookingType: .hotel,
        startAt: Date(timeIntervalSince1970: 0),
        endAt: Date(timeIntervalSince1970: 86_400),
        locationToAddress: munichAddress,
        status: .confirmed
    )
    #expect(SpatialGapDetector.fromEndPlaceLabel(hotel) == nil)
    #expect(SpatialGapDetector.fromEndPlace(hotel) == munichAddress)
}

@Test func toStartPlaceLabel_prefersCityOverAddress() {
    let flight = Booking(
        provider: .manual,
        bookingType: .flight,
        startAt: Date(timeIntervalSince1970: 0),
        endAt: Date(timeIntervalSince1970: 3_600),
        locationFrom: "Berlin",
        locationFromAddress: "Terminal 1, 12529 Berlin",
        status: .confirmed
    )
    #expect(SpatialGapDetector.toStartPlaceLabel(flight) == "Berlin")
}

@Test func spatial_transportDesired_usesCityLabelsNotAddress() {
    let day: TimeInterval = 24 * 60 * 60
    let hotel = Booking(
        provider: .manual,
        bookingType: .hotel,
        startAt: Date(timeIntervalSince1970: 0),
        endAt: Date(timeIntervalSince1970: day),
        locationTo: "Paris",
        locationToAddress: parisAddress,
        status: .confirmed
    )
    let flight = Booking(
        provider: .manual,
        bookingType: .flight,
        startAt: Date(timeIntervalSince1970: 5 * day),
        endAt: Date(timeIntervalSince1970: 5 * day + 3_600),
        locationFrom: "Berlin",
        locationTo: "FRA",
        locationFromAddress: "Terminal 1, 12529 Berlin",
        status: .confirmed
    )
    let gaps = SpatialGapDetector.detect(sortedReal: [hotel, flight])
    #expect(gaps.count == 1)
    #expect(gaps[0].locationFrom == "Paris")
    #expect(gaps[0].locationTo == "Berlin")
    #expect(gaps[0].locationFrom != parisAddress)
}

@Test func spatial_addressOnly_stillDetectsPlaceChange_butLeavesLocationsEmpty() {
    let day: TimeInterval = 24 * 60 * 60
    let hotel = Booking(
        provider: .manual,
        bookingType: .hotel,
        startAt: Date(timeIntervalSince1970: 0),
        endAt: Date(timeIntervalSince1970: day),
        locationToAddress: parisAddress,
        status: .confirmed
    )
    let flight = Booking(
        provider: .manual,
        bookingType: .flight,
        startAt: Date(timeIntervalSince1970: 5 * day),
        endAt: Date(timeIntervalSince1970: 5 * day + 3_600),
        locationFrom: "Berlin",
        locationTo: "FRA",
        status: .confirmed
    )
    let gaps = SpatialGapDetector.detect(sortedReal: [hotel, flight])
    #expect(gaps.count == 1)
    #expect(gaps[0].locationFrom == nil)
    #expect(gaps[0].locationTo == "Berlin")
}
