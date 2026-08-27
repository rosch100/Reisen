import Foundation
import Testing
import ReisenDomain

private let germanDevice = Locale(identifier: "de_DE")

private func booking(
    id: UUID = UUID(),
    startAt: Date = Date(timeIntervalSince1970: 1_000_000),
    locationTo: String? = nil,
    locationToAddress: String? = nil,
    locationFromAddress: String? = nil
) -> Booking {
    Booking(
        id: id,
        provider: .opodo,
        bookingType: .hotel,
        startAt: startAt,
        endAt: startAt.addingTimeInterval(86_400),
        locationTo: locationTo,
        locationFromAddress: locationFromAddress,
        locationToAddress: locationToAddress,
        status: .confirmed
    )
}

@Test func tripTitleSuggestion_cityOnlyWhenSameCountry() {
    let result = TripTitleSuggestion.from(
        bookings: [
            booking(
                locationTo: "München",
                locationToAddress: "Example 1, 80331 München, DE"
            )
        ],
        locale: germanDevice
    )
    #expect(result == "München")
}

@Test func tripTitleSuggestion_cityAndForeignCountry() {
    let result = TripTitleSuggestion.from(
        bookings: [
            booking(
                locationTo: "Jakarta",
                locationToAddress: "Jl. Example 29 - 31, 10130 Jakarta, ID"
            )
        ],
        locale: germanDevice
    )
    #expect(result == "Jakarta, Indonesien")
}

@Test func tripTitleSuggestion_cityWithoutIsoCountryCode() {
    let result = TripTitleSuggestion.from(
        bookings: [
            booking(
                locationTo: "South Jakarta",
                locationToAddress: "Jl. Example, Cilandak, South Jakarta"
            )
        ],
        locale: germanDevice
    )
    #expect(result == "South Jakarta")
}

@Test func tripTitleSuggestion_foreignCountryOnlyWithoutCity() {
    let result = TripTitleSuggestion.from(
        bookings: [
            booking(locationToAddress: "Some Airport, ID")
        ],
        locale: germanDevice
    )
    #expect(result == "Indonesien")
}

@Test func tripTitleSuggestion_domesticWithoutCityReturnsNil() {
    let result = TripTitleSuggestion.from(
        bookings: [
            booking(locationToAddress: "Example Street, DE")
        ],
        locale: germanDevice
    )
    #expect(result == nil)
}

@Test func tripTitleSuggestion_usesEarliestBooking() {
    let laterID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    let earlierID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    let result = TripTitleSuggestion.from(
        bookings: [
            booking(
                id: laterID,
                startAt: Date(timeIntervalSince1970: 2_000_000),
                locationTo: "Berlin",
                locationToAddress: "Example, DE"
            ),
            booking(
                id: earlierID,
                startAt: Date(timeIntervalSince1970: 1_000_000),
                locationTo: "Jakarta",
                locationToAddress: "Example, ID"
            )
        ],
        locale: germanDevice
    )
    #expect(result == "Jakarta, Indonesien")
}

@Test func tripTitleSuggestion_emptyBookingsReturnsNil() {
    #expect(TripTitleSuggestion.from(bookings: [], locale: germanDevice) == nil)
}

@Test func tripTitleSuggestion_doesNotUseOriginCountryAsDestination() {
    let withCity = TripTitleSuggestion.from(
        bookings: [
            booking(
                locationTo: "Berlin",
                locationToAddress: "Alexanderplatz, Berlin",
                locationFromAddress: "Some Airport, ID"
            )
        ],
        locale: germanDevice
    )
    #expect(withCity == "Berlin")

    let originOnly = TripTitleSuggestion.from(
        bookings: [
            booking(locationFromAddress: "Some Airport, ID")
        ],
        locale: germanDevice
    )
    #expect(originOnly == nil)
}
