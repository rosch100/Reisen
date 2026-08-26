import Foundation
import SwiftData
import CloudKit
import ReisenDomain

/// Launch-argument / env driven two-device CloudKit verification (seed on A, expect on B).
///
/// Activate with `SIMCTL_CHILD_REISEN_VERIFY_SEED=1` or `SIMCTL_CHILD_REISEN_VERIFY_EXPECT=1`
/// (see `Scripts/verify-two-device-icloud.sh`).
@MainActor
public enum CloudKitTwoDeviceVerification {
    public static let tripID = UUID(uuidString: "C10D51C0-0001-4000-8000-000000000001")!
    public static let bookingFromID = UUID(uuidString: "C10D51C0-0001-4000-8000-000000000002")!
    public static let bookingToID = UUID(uuidString: "C10D51C0-0001-4000-8000-000000000003")!
    public static let gapID = UUID(uuidString: "C10D51C0-0001-4000-8000-000000000004")!
    public static let localReminderID = UUID(uuidString: "C10D51C0-0001-4000-8000-000000000099")!

    public static let resultFileName = "verify-two-device-result.json"

    private static let seedFlag = "REISEN_VERIFY_SEED"
    private static let expectFlag = "REISEN_VERIFY_EXPECT"
    private static let expectTimeout: TimeInterval = 90
    private static let exportTimeout: Duration = .seconds(45)

    public static func runIfRequested(modelContext: ModelContext) async {
        let mode = requestedMode()
        guard mode != .none else { return }

        do {
            switch mode {
            case .seed:
                try await seed(modelContext: modelContext)
            case .expect:
                try await expect(modelContext: modelContext)
            case .none:
                break
            }
        } catch {
            try? writeResult(VerifyResult(mode: mode, ok: false, message: String(describing: error)))
        }
    }

    private enum Mode: String {
        case none
        case seed
        case expect
    }

    private struct VerifyResult: Encodable {
        var mode: String
        var ok: Bool
        var message: String
        var cloudKitEnabled: Bool?
        var accountStatus: String?
        var tripID: String?
        var bookingFromID: String?
        var bookingToID: String?
        var gapID: String?
        var localReminderID: String?
        var tripFound: Bool?
        var bookingFromFound: Bool?
        var bookingToFound: Bool?
        var gapFound: Bool?
        var localReminderFound: Bool?

        init(mode: Mode, ok: Bool, message: String) {
            self.mode = mode.rawValue
            self.ok = ok
            self.message = message
        }
    }

    private static func requestedMode() -> Mode {
        let env = ProcessInfo.processInfo.environment
        let args = ProcessInfo.processInfo.arguments
        if isFlagSet(seedFlag, env: env, args: args) { return .seed }
        if isFlagSet(expectFlag, env: env, args: args) { return .expect }
        return .none
    }

    private static func isFlagSet(_ name: String, env: [String: String], args: [String]) -> Bool {
        env[name] == "1" || args.contains("-\(name)")
    }

    /// Writes a failure result and returns `nil` when CloudKit/account is not ready.
    private static func cloudKitAccountIfReady(mode: Mode) async throws -> CKAccountStatus? {
        let account = await PersistenceBootstrap.fetchCloudKitAccountStatus()
        let enabled = PersistenceBootstrap.isCloudKitEnabledByEnvironment()
        let statusName = accountStatusName(account)

        guard enabled else {
            var result = VerifyResult(
                mode: mode,
                ok: false,
                message: mode == .seed
                    ? "CloudKit disabled (REISEN_CLOUDKIT=0 / CI / XCTest)."
                    : "CloudKit disabled."
            )
            result.cloudKitEnabled = false
            result.accountStatus = statusName
            try writeResult(result)
            return nil
        }

        guard account == .available else {
            var result = VerifyResult(
                mode: mode,
                ok: false,
                message: mode == .seed
                    ? "iCloud-Account nicht verfügbar — bitte auf beiden Geräten denselben Account anmelden."
                    : "iCloud-Account nicht verfügbar auf Gerät B."
            )
            result.cloudKitEnabled = true
            result.accountStatus = statusName
            try writeResult(result)
            return nil
        }

        return account
    }

    private static func seed(modelContext: ModelContext) async throws {
        guard let account = try await cloudKitAccountIfReady(mode: .seed) else { return }

        try deleteVerificationEntities(in: modelContext)
        insertSeedGraph(into: modelContext)
        try modelContext.save()
        await PersistenceBootstrap.awaitCloudKitExportIfNeeded(timeout: exportTimeout)

        var result = VerifyResult(
            mode: .seed,
            ok: true,
            message: "Seed geschrieben und CloudKit-Export abgewartet."
        )
        result.cloudKitEnabled = true
        result.accountStatus = accountStatusName(account)
        result.tripID = tripID.uuidString
        result.bookingFromID = bookingFromID.uuidString
        result.bookingToID = bookingToID.uuidString
        result.gapID = gapID.uuidString
        result.localReminderID = localReminderID.uuidString
        try writeResult(result)
    }

    private static func expect(modelContext: ModelContext) async throws {
        guard let account = try await cloudKitAccountIfReady(mode: .expect) else { return }

        let cloud = try await waitForCloudEntities(in: modelContext)
        let localReminderFound = try reminderExists(localReminderID, in: modelContext)
        let ok = cloud.allFound && !localReminderFound

        var result = VerifyResult(
            mode: .expect,
            ok: ok,
            message: expectMessage(cloud: cloud, localReminderFound: localReminderFound)
        )
        result.cloudKitEnabled = true
        result.accountStatus = accountStatusName(account)
        result.tripFound = cloud.tripFound
        result.bookingFromFound = cloud.bookingFromFound
        result.bookingToFound = cloud.bookingToFound
        result.gapFound = cloud.gapFound
        result.localReminderFound = localReminderFound
        try writeResult(result)
    }

    private struct CloudPresence {
        var tripFound = false
        var bookingFromFound = false
        var bookingToFound = false
        var gapFound = false

        var allFound: Bool {
            tripFound && bookingFromFound && bookingToFound && gapFound
        }
    }

    private static func waitForCloudEntities(in context: ModelContext) async throws -> CloudPresence {
        var cloud = CloudPresence()
        let deadline = Date().addingTimeInterval(expectTimeout)
        while Date() < deadline {
            await PersistenceBootstrap.awaitCloudKitImportIfNeeded(timeout: .seconds(5))
            cloud.tripFound = try tripExists(tripID, in: context)
            cloud.bookingFromFound = try bookingExists(bookingFromID, in: context)
            cloud.bookingToFound = try bookingExists(bookingToID, in: context)
            cloud.gapFound = try gapExists(gapID, in: context)
            if cloud.allFound { break }
            try await Task.sleep(for: .seconds(2))
        }
        return cloud
    }

    private static func expectMessage(cloud: CloudPresence, localReminderFound: Bool) -> String {
        if !cloud.allFound {
            return "Cloud-Daten unvollständig oder Sync noch nicht angekommen."
        }
        if localReminderFound {
            return "Lokales Reminder wurde fälschlich synchronisiert."
        }
        return "Trip/Bookings/Gap aus iCloud sichtbar; lokales Reminder nicht vorhanden."
    }

    private static func insertSeedGraph(into context: ModelContext) {
        let start = Calendar.current.startOfDay(for: Date().addingTimeInterval(86_400))
        let mid = start.addingTimeInterval(86_400)
        let end = start.addingTimeInterval(86_400 * 3)

        let trip = SDTrip(
            id: tripID,
            title: "CloudKit Two-Device Verify",
            startDate: start,
            endDate: end,
            destination: "VerifyCity"
        )
        context.insert(trip)

        let bookingFrom = SDBooking(
            id: bookingFromID,
            providerRaw: ProviderID.manual.rawValue,
            bookingTypeRaw: BookingType.hotel.rawValue,
            title: "Hotel A",
            externalUrl: "https://example.com/reisen-verify-a",
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
            externalUrl: "https://example.com/reisen-verify-b",
            startAt: mid.addingTimeInterval(86_400),
            endAt: end,
            statusRaw: BookingStatus.confirmed.rawValue,
            trip: trip
        )
        context.insert(bookingTo)

        context.insert(SDGap(
            id: gapID,
            trip: trip,
            fromBooking: bookingFrom,
            toBooking: bookingTo,
            gapStart: mid,
            gapEnd: mid.addingTimeInterval(86_400),
            kindRaw: GapKind.lodging.rawValue,
            titleOverride: "Verify Gap",
            identityKey: "verify|\(bookingFromID.uuidString)|\(bookingToID.uuidString)"
        ))

        context.insert(SDReminder(
            id: localReminderID,
            fireAt: start.addingTimeInterval(-3_600),
            targetRaw: ReminderTarget.custom.rawValue,
            channelRaw: ReminderChannel.notification.rawValue,
            statusRaw: ReminderStatus.scheduled.rawValue,
            title: "Device-local only",
            gapID: gapID,
            externalAlarmId: "local-verify-alarm"
        ))
    }

    private static func deleteVerificationEntities(in context: ModelContext) throws {
        try deleteTrips(id: tripID, in: context)
        try deleteBookings(id: bookingFromID, in: context)
        try deleteBookings(id: bookingToID, in: context)
        try deleteGaps(id: gapID, in: context)
        try deleteReminders(id: localReminderID, in: context)
        try context.save()
    }

    private static func deleteTrips(id: UUID, in context: ModelContext) throws {
        let matchID = id
        for model in try context.fetch(FetchDescriptor<SDTrip>(predicate: #Predicate { $0.id == matchID })) {
            context.delete(model)
        }
    }

    private static func deleteBookings(id: UUID, in context: ModelContext) throws {
        let matchID = id
        for model in try context.fetch(FetchDescriptor<SDBooking>(predicate: #Predicate { $0.id == matchID })) {
            context.delete(model)
        }
    }

    private static func deleteGaps(id: UUID, in context: ModelContext) throws {
        let matchID = id
        for model in try context.fetch(FetchDescriptor<SDGap>(predicate: #Predicate { $0.id == matchID })) {
            context.delete(model)
        }
    }

    private static func deleteReminders(id: UUID, in context: ModelContext) throws {
        let matchID = id
        for model in try context.fetch(FetchDescriptor<SDReminder>(predicate: #Predicate { $0.id == matchID })) {
            context.delete(model)
        }
    }

    private static func tripExists(_ id: UUID, in context: ModelContext) throws -> Bool {
        let matchID = id
        return try context.fetch(FetchDescriptor<SDTrip>(predicate: #Predicate { $0.id == matchID })).first != nil
    }

    private static func bookingExists(_ id: UUID, in context: ModelContext) throws -> Bool {
        let matchID = id
        return try context.fetch(FetchDescriptor<SDBooking>(predicate: #Predicate { $0.id == matchID })).first != nil
    }

    private static func gapExists(_ id: UUID, in context: ModelContext) throws -> Bool {
        let matchID = id
        return try context.fetch(FetchDescriptor<SDGap>(predicate: #Predicate { $0.id == matchID })).first != nil
    }

    private static func reminderExists(_ id: UUID, in context: ModelContext) throws -> Bool {
        let matchID = id
        return try context.fetch(FetchDescriptor<SDReminder>(predicate: #Predicate { $0.id == matchID })).first != nil
    }

    private static func accountStatusName(_ status: CKAccountStatus) -> String {
        switch status {
        case .couldNotDetermine: return "couldNotDetermine"
        case .available: return "available"
        case .restricted: return "restricted"
        case .noAccount: return "noAccount"
        case .temporarilyUnavailable: return "temporarilyUnavailable"
        @unknown default: return "unknown"
        }
    }

    private static func writeResult(_ result: VerifyResult) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(result).write(to: try resultURL(), options: .atomic)
    }

    private static func resultURL() throws -> URL {
        try PersistenceBootstrap.supportDirectory().appendingPathComponent(resultFileName)
    }
}
