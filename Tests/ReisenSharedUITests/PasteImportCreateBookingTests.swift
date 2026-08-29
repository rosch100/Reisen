import Foundation
import SwiftData
import Testing
import ReisenData
import ReisenDomain
import ReisenSharedUI

private let createStart = Date(timeIntervalSince1970: 1_800_000_000)
private let createEnd = createStart.addingTimeInterval(86_400)

private func pastedDraft() -> BookingEditorDraft {
    var draft = BookingEditorDraft.createDefault(
        tripStartDate: createStart,
        prefillStart: createStart,
        prefillEnd: createEnd
    )
    draft.title = "Hotel Lissabon"
    return draft
}

@MainActor
private func persistedBooking(id: UUID, in context: ModelContext) throws -> SDBooking {
    let bookings = try context.fetch(FetchDescriptor<SDBooking>())
    return try #require(bookings.first { $0.id == id })
}

@MainActor
@Test func pasteImportCreateBooking_withoutTrip_staysOpen() throws {
    let container = try PersistenceBootstrap.makeInMemoryContainer()
    let context = container.mainContext

    let bookingID = try BookingEditorDraft.createBooking(
        from: pastedDraft(),
        trip: nil,
        in: context
    )

    let booking = try persistedBooking(id: bookingID, in: context)
    #expect(booking.trip == nil)
    #expect(booking.providerRaw == ProviderID.manual.rawValue)
    #expect(booking.title == "Hotel Lissabon")
}

@MainActor
@Test func pasteImportCreateBooking_withTrip_assignsTrip() throws {
    let container = try PersistenceBootstrap.makeInMemoryContainer()
    let context = container.mainContext

    let trip = SDTrip(title: "Portugal", startDate: createStart, endDate: createEnd)
    context.insert(trip)

    let bookingID = try BookingEditorDraft.createBooking(
        from: pastedDraft(),
        trip: trip,
        in: context
    )

    let booking = try persistedBooking(id: bookingID, in: context)
    #expect(booking.trip?.id == trip.id)
    #expect(booking.providerRaw == ProviderID.manual.rawValue)
}
