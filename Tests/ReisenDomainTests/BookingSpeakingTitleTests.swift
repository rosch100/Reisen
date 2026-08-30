import Foundation
import Testing
import ReisenDomain

private enum SpeakingTitleFixture {
    static let start = Date(timeIntervalSince1970: 1_800_000_000)

    static func draft(
        type: BookingType,
        title: String? = nil,
        from: String? = nil,
        to: String? = nil,
        operatorName: String? = nil
    ) throws -> PasteImportDraft {
        try #require(
            PasteImportDraft(
                from: PasteImportExtraction(
                    bookingType: type,
                    startAt: start,
                    title: title,
                    locationFrom: from,
                    locationTo: to,
                    operatorName: operatorName
                )
            )
        )
    }
}

@Test func pasteImportDraft_flightUsesRouteTitleNotFlightNumber() throws {
    let draft = try SpeakingTitleFixture.draft(
        type: .flight,
        title: "UA 1449",
        from: "Vancouver YVR",
        to: "San Francisco SFO"
    )
    #expect(draft.title == PlaceLabel.route(from: "Vancouver YVR", to: "San Francisco SFO"))
}

@Test func pasteImportDraft_trainUsesRouteTitleNotTrainNumber() throws {
    let draft = try SpeakingTitleFixture.draft(
        type: .train,
        title: "ICE 512",
        from: "Berlin Hbf",
        to: "München Hbf"
    )
    #expect(draft.title == PlaceLabel.route(from: "Berlin Hbf", to: "München Hbf"))
}

@Test func pasteImportDraft_hotelKeepsHotelName() throws {
    let draft = try SpeakingTitleFixture.draft(
        type: .hotel,
        title: "Hotel Deloix",
        to: "Benidorm",
        operatorName: "Hotel Deloix"
    )
    #expect(draft.title == "Hotel Deloix")
}

@Test func pasteImportDraft_activityKeepsEventName() throws {
    let draft = try SpeakingTitleFixture.draft(
        type: .activity,
        title: "Jazz Night",
        to: "Sample Hall, Berlin"
    )
    #expect(draft.title == "Jazz Night")
}

@Test func pasteImportDraft_carRentalKeepsSpeakingTitle() throws {
    let draft = try SpeakingTitleFixture.draft(
        type: .carRental,
        title: "Economy München Flughafen",
        from: "München Flughafen",
        to: "München Flughafen"
    )
    #expect(draft.title == "Economy München Flughafen")
}

@Test func pasteImportDraft_ferryUsesRouteTitle() throws {
    let draft = try SpeakingTitleFixture.draft(
        type: .ferry,
        title: "Fährticket",
        from: "Puttgarden",
        to: "Rødby"
    )
    #expect(draft.title == PlaceLabel.route(from: "Puttgarden", to: "Rødby"))
}

@Test func pasteImportDraft_flightWithoutRouteKeepsExtractedTitle() throws {
    let draft = try SpeakingTitleFixture.draft(type: .flight, title: "UA 1449")
    #expect(draft.title == "UA 1449")
}

@Test func pasteImportDraft_hotelWithoutTitleUsesOperatorName() throws {
    let draft = try SpeakingTitleFixture.draft(
        type: .hotel,
        to: "Heidelberg",
        operatorName: "Pension Lindenhof"
    )
    #expect(draft.title == "Pension Lindenhof")
}

@Test func pasteImportDraft_flightWithOnlyDestinationUsesPlace() throws {
    let draft = try SpeakingTitleFixture.draft(type: .flight, title: "UA 1449", to: "JFK")
    #expect(draft.title == "JFK")
}

@Test func pasteImportDraft_carRentalWithoutTitleUsesRoute() throws {
    let draft = try SpeakingTitleFixture.draft(
        type: .carRental,
        from: "Berlin",
        to: "München"
    )
    #expect(draft.title == PlaceLabel.route(from: "Berlin", to: "München"))
}


