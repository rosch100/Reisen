import Testing
import Foundation
import SwiftData
import ReisenData
import ReisenDomain
import ReisenSharedUI

@MainActor
@Test func presentationTitle_appendsAutoGapBadge() throws {
    let booking = SDBooking(
        providerRaw: ProviderID.autoGap.rawValue,
        bookingTypeRaw: BookingType.hotel.rawValue,
        title: "Hotel",
        startAt: Date(timeIntervalSince1970: 1),
        endAt: Date(timeIntervalSince1970: 2),
        statusRaw: BookingStatus.unknown.rawValue,
        autoGapIdentityKey: "a|b|lodging"
    )
    #expect(booking.presentationTitle.contains(L10n.string(.bookingAutoGapBadge)))
}

@MainActor
@Test func bookingEditorApply_promotesAutoGapToManual() throws {
    let container = try PersistenceBootstrap.makeInMemoryContainer()
    let context = container.mainContext
    let trip = SDTrip(
        id: UUID(),
        title: "T",
        startDate: Date(timeIntervalSince1970: 1_000_000),
        endDate: Date(timeIntervalSince1970: 1_900_000)
    )
    context.insert(trip)
    let booking = SDBooking(
        providerRaw: ProviderID.autoGap.rawValue,
        bookingTypeRaw: BookingType.hotel.rawValue,
        title: "Auto Hotel",
        startAt: Date(timeIntervalSince1970: 1_200_000),
        endAt: Date(timeIntervalSince1970: 1_500_000),
        statusRaw: BookingStatus.unknown.rawValue,
        autoGapIdentityKey: "a|b|lodging",
        trip: trip
    )
    context.insert(booking)
    try context.save()

    var draft = BookingEditorDraft.fromExisting(booking)
    draft.title = "Promoted Hotel"
    try draft.apply(to: booking, in: context)

    #expect(booking.provider == .manual)
    #expect(booking.autoGapIdentityKey == nil)
    #expect(booking.title == "Promoted Hotel")
}
