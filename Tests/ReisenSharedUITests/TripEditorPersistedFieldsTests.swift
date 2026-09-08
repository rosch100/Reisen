import Foundation
import SwiftData
import Testing
import ReisenData
import ReisenSharedUI

@Test func tripEditorPersistedFields_optionalTextTrimsEmptyToNil() {
    #expect(TripEditorPersistedFields.optionalStored("  ") == nil)
    #expect(TripEditorPersistedFields.optionalStored("") == nil)
    #expect(TripEditorPersistedFields.optionalStored(" Lisboa ") == "Lisboa")
}

@MainActor
@Test func tripEditorPersistedFields_applyWritesDestinationAndNotes() throws {
    let container = try PersistenceBootstrap.makeInMemoryContainer()
    let context = container.mainContext
    let trip = SDTrip(
        title: "Alt",
        startDate: Date(timeIntervalSince1970: 1_700_000_000),
        endDate: Date(timeIntervalSince1970: 1_700_086_400),
        destination: nil,
        notes: nil
    )
    context.insert(trip)

    TripEditorPersistedFields.apply(
        title: "Portugal",
        startDate: trip.startDate,
        endDate: trip.endDate,
        destinationRaw: " Lissabon ",
        notesRaw: "  Strand ",
        to: trip
    )
    try context.save()

    #expect(trip.title == "Portugal")
    #expect(trip.destination == "Lissabon")
    #expect(trip.notes == "Strand")
}

@MainActor
@Test func tripEditorPersistedFields_applyClearsBlankDestinationAndNotes() throws {
    let container = try PersistenceBootstrap.makeInMemoryContainer()
    let context = container.mainContext
    let trip = SDTrip(
        title: "Trip",
        startDate: Date(timeIntervalSince1970: 1_700_000_000),
        endDate: Date(timeIntervalSince1970: 1_700_086_400),
        destination: "Alt",
        notes: "Notiz"
    )
    context.insert(trip)

    TripEditorPersistedFields.apply(
        title: "Trip",
        startDate: trip.startDate,
        endDate: trip.endDate,
        destinationRaw: "   ",
        notesRaw: "",
        to: trip
    )
    try context.save()

    #expect(trip.destination == nil)
    #expect(trip.notes == nil)
}
