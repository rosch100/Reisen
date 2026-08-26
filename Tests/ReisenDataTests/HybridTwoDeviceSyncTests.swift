import Testing
import Foundation
import SwiftData
import ReisenData
import ReisenDomain

/// Simulates two devices sharing the same cloud store file while keeping local stores separate.
@MainActor
@Test func hybridTwoDeviceCloudStoreSyncsTripBookingGapButNotLocalReminder() throws {
    let fm = FileManager.default
    let root = fm.temporaryDirectory.appendingPathComponent("reisen-two-device-\(UUID().uuidString)", isDirectory: true)
    try fm.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? fm.removeItem(at: root) }

    let sharedCloud = root.appendingPathComponent("shared-cloud.sqlite")
    let localA = root.appendingPathComponent("local-a.sqlite")
    let localB = root.appendingPathComponent("local-b.sqlite")

    let tripID = CloudKitTwoDeviceVerification.tripID
    let bookingFromID = CloudKitTwoDeviceVerification.bookingFromID
    let bookingToID = CloudKitTwoDeviceVerification.bookingToID
    let gapID = CloudKitTwoDeviceVerification.gapID
    let reminderID = CloudKitTwoDeviceVerification.localReminderID

    // Device A writes cloud + local entities.
    do {
        let deviceA = try PersistenceBootstrap.makeDualContainer(
            cloudStoreURL: sharedCloud,
            localStoreURL: localA
        )
        let context = deviceA.mainContext

        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let mid = start.addingTimeInterval(86_400)
        let end = start.addingTimeInterval(86_400 * 3)

        let trip = SDTrip(
            id: tripID,
            title: "Two Device Trip",
            startDate: start,
            endDate: end
        )
        context.insert(trip)

        let bookingFrom = SDBooking(
            id: bookingFromID,
            providerRaw: ProviderID.manual.rawValue,
            bookingTypeRaw: BookingType.hotel.rawValue,
            title: "Hotel A",
            startAt: start,
            endAt: mid,
            statusRaw: BookingStatus.confirmed.rawValue,
            trip: trip
        )
        context.insert(bookingFrom)

        let bookingTo = SDBooking(
            id: bookingToID,
            providerRaw: ProviderID.manual.rawValue,
            bookingTypeRaw: BookingType.hotel.rawValue,
            title: "Hotel B",
            startAt: mid.addingTimeInterval(86_400),
            endAt: end,
            statusRaw: BookingStatus.confirmed.rawValue,
            trip: trip
        )
        context.insert(bookingTo)

        let gap = SDGap(
            id: gapID,
            trip: trip,
            fromBooking: bookingFrom,
            toBooking: bookingTo,
            gapStart: mid,
            gapEnd: mid.addingTimeInterval(86_400),
            kindRaw: GapKind.lodging.rawValue,
            identityKey: "two-device-gap"
        )
        context.insert(gap)

        let reminder = SDReminder(
            id: reminderID,
            fireAt: start,
            targetRaw: ReminderTarget.custom.rawValue,
            channelRaw: ReminderChannel.notification.rawValue,
            statusRaw: ReminderStatus.scheduled.rawValue,
            gapID: gapID,
            externalAlarmId: "device-a-only"
        )
        context.insert(reminder)
        try context.save()
    }

    // Device B opens the same cloud file with a fresh local store.
    let deviceB = try PersistenceBootstrap.makeDualContainer(
        cloudStoreURL: sharedCloud,
        localStoreURL: localB
    )
    let contextB = deviceB.mainContext

    let trips = try contextB.fetch(FetchDescriptor<SDTrip>(predicate: #Predicate { $0.id == tripID }))
    #expect(trips.count == 1)
    #expect(trips.first?.title == "Two Device Trip")

    let bookings = try contextB.fetch(FetchDescriptor<SDBooking>())
    let bookingIDs = Set(bookings.map(\.id))
    #expect(bookingIDs == Set([bookingFromID, bookingToID]))

    let gaps = try contextB.fetch(FetchDescriptor<SDGap>(predicate: #Predicate { $0.id == gapID }))
    #expect(gaps.count == 1)

    let reminders = try contextB.fetch(FetchDescriptor<SDReminder>(predicate: #Predicate { $0.id == reminderID }))
    #expect(reminders.isEmpty)

    // Device A local store still holds the reminder.
    let deviceAAgain = try PersistenceBootstrap.makeDualContainer(
        cloudStoreURL: sharedCloud,
        localStoreURL: localA
    )
    let remindersA = try deviceAAgain.mainContext.fetch(
        FetchDescriptor<SDReminder>(predicate: #Predicate { $0.id == reminderID })
    )
    #expect(remindersA.count == 1)
    #expect(remindersA.first?.externalAlarmId == "device-a-only")
}
