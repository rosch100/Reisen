import Testing
import Foundation
import SwiftData
import ReisenData
import ReisenDomain

@Test func persistenceBootstrapCreatesContainer() throws {
    #expect(!ReisenSchemaV1.models.isEmpty)
    #expect(!ReisenSchemaV10.models.isEmpty)
    #expect(ReisenMigrationPlan.schemas.contains { $0 == ReisenSchemaV10.self })
    #expect(ReisenMigrationPlan.stages.isEmpty)
    #expect(PersistenceBootstrap.cloudKitContainerID.hasPrefix("iCloud."))
    #expect(PersistenceBootstrap.cloudKitContainerID.hasSuffix(".Reisen"))
    #expect(PersistenceBootstrap.cloudStoreName == "reisen-cloud")
    #expect(PersistenceBootstrap.localStoreName == "reisen-local")
    #expect(!ReisenSchemaV10.cloudModels.isEmpty)
    #expect(!ReisenSchemaV10.localModels.isEmpty)
}

@MainActor
@Test func hybridStoreSplitKeepsCloudAndLocalModelsApart() throws {
    let cloudTypes = Set(ReisenSchemaV10.cloudModels.map { ObjectIdentifier($0) })
    let localTypes = Set(ReisenSchemaV10.localModels.map { ObjectIdentifier($0) })
    #expect(cloudTypes.isDisjoint(with: localTypes))

    #expect(cloudTypes.contains(ObjectIdentifier(SDTrip.self)))
    #expect(cloudTypes.contains(ObjectIdentifier(SDBooking.self)))
    #expect(cloudTypes.contains(ObjectIdentifier(SDGap.self)))
    #expect(cloudTypes.contains(ObjectIdentifier(SDAutoGapSuppress.self)))

    #expect(localTypes.contains(ObjectIdentifier(SDReminder.self)))
    #expect(localTypes.contains(ObjectIdentifier(SDCalendarEventLink.self)))
    #expect(localTypes.contains(ObjectIdentifier(SDCancellationDeadlineLink.self)))
    #expect(localTypes.contains(ObjectIdentifier(SDPreTravelHintLink.self)))

    let container = try PersistenceBootstrap.makeInMemoryContainer()
    let context = container.mainContext

    let trip = SDTrip(
        id: UUID(),
        title: "Split",
        startDate: Date(timeIntervalSince1970: 1_700_000_000),
        endDate: Date(timeIntervalSince1970: 1_700_100_000)
    )
    context.insert(trip)

    let reminder = SDReminder(
        id: UUID(),
        fireAt: Date(timeIntervalSince1970: 1_699_000_000),
        targetRaw: ReminderTarget.cancellationDeadline.rawValue,
        channelRaw: ReminderChannel.notification.rawValue,
        statusRaw: ReminderStatus.scheduled.rawValue,
        title: "local-only"
    )
    context.insert(reminder)
    try context.save()

    let trips = try context.fetch(FetchDescriptor<SDTrip>())
    let reminders = try context.fetch(FetchDescriptor<SDReminder>())
    #expect(trips.count == 1)
    #expect(reminders.count == 1)
    #expect(trips[0].title == "Split")
    #expect(reminders[0].title == "local-only")
}

@MainActor
@Test func cloudKitDisabledInTestEnvironment() {
    #expect(PersistenceBootstrap.isCloudKitEnabledByEnvironment() == false)
}

@Test func cloudKitRequiresSigningTeamIdentifier() {
    #expect(cloudKitGuardEnabled())
    #expect(!cloudKitGuardEnabled(team: nil))
    #expect(!cloudKitGuardEnabled(team: ""))
    #expect(!cloudKitGuardEnabled(appID: nil))
    #expect(!cloudKitGuardEnabled(env: ["CI": "true"]))
}

@Test func cloudKitRequiresICloudEntitlements() {
    #expect(!cloudKitGuardEnabled(containers: []))
    #expect(!cloudKitGuardEnabled(containers: ["iCloud.other.container"]))
    #expect(!cloudKitGuardEnabled(services: []))
    #expect(!cloudKitGuardEnabled(services: ["CloudDocuments"]))
    #expect(cloudKitGuardEnabled(services: ["*"]))
}

@Test func cloudKitRequiresScalarContainerEnvironment() {
    #expect(!cloudKitGuardEnabled(containerEnvironment: nil))
    #expect(!cloudKitGuardEnabled(containerEnvironment: ""))
    #expect(!cloudKitGuardEnabled(containerEnvironment: "development"))
    #expect(!cloudKitGuardEnabled(containerEnvironment: "Production, Development"))
    #expect(cloudKitGuardEnabled(containerEnvironment: "Development"))
    #expect(cloudKitGuardEnabled(containerEnvironment: "Production"))
}

@Test(.enabled(if: ProcessInfo.processInfo.environment["REISEN_LEFTOVER_CLOUD_DIR"] != nil))
@MainActor
func leftoverCloudKitStoreOpensWithMirroringDisabled() throws {
    let dirPath = try #require(ProcessInfo.processInfo.environment["REISEN_LEFTOVER_CLOUD_DIR"])
    let fm = FileManager.default
    let sourceCloud = URL(fileURLWithPath: dirPath).appendingPathComponent("ReisenCloud.sqlite")
    try #require(fm.fileExists(atPath: sourceCloud.path))

    let root = fm.temporaryDirectory.appendingPathComponent(
        "reisen-leftover-\(UUID().uuidString)",
        isDirectory: true
    )
    try fm.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? fm.removeItem(at: root) }

    let cloud = root.appendingPathComponent("cloud.sqlite")
    let local = root.appendingPathComponent("local.sqlite")
    for suffix in ["", "-wal", "-shm"] {
        let from = URL(fileURLWithPath: sourceCloud.path + suffix)
        guard fm.fileExists(atPath: from.path) else { continue }
        try fm.copyItem(at: from, to: URL(fileURLWithPath: cloud.path + suffix))
    }

    let container = try PersistenceBootstrap.makeDualContainer(
        cloudStoreURL: cloud,
        localStoreURL: local
    )
    let trips = try container.mainContext.fetch(FetchDescriptor<SDTrip>())
    #expect(trips.count >= 0)
}

private func cloudKitGuardEnabled(
    env: [String: String] = [:],
    team: String? = "TEAMID0000",
    appID: String? = "TEAMID0000.de.roschmac.Reisen",
    containers: [String] = [PersistenceBootstrap.cloudKitContainerID],
    services: [String] = ["CloudKit"],
    containerEnvironment: String? = "Development"
) -> Bool {
    PersistenceBootstrap.isCloudKitEnabled(
        environment: env,
        processName: "Reisen",
        arguments: [],
        teamIdentifier: team,
        applicationIdentifier: appID,
        icloudContainerIdentifiers: containers,
        icloudServices: services,
        icloudContainerEnvironment: containerEnvironment
    )
}

@Test func appSettingsFromUserDefaultsReadsPersistedValues() {
    let suiteName = "reisen.tests.AppSettings.\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: suiteName) else {
        Issue.record("UserDefaults suite unavailable")
        return
    }
    defer { defaults.removePersistentDomain(forName: suiteName) }

    defaults.set(false, forKey: AppSettingsKeys.notificationEnabled)
    defaults.set(true, forKey: AppSettingsKeys.eventKitEnabled)
    defaults.set("MeinKalender", forKey: AppSettingsKeys.calendarTitle)
    defaults.set("7,1", forKey: AppSettingsKeys.leadTimesDays)
    defaults.set(CalendarTitleMode.fixed.rawValue, forKey: AppSettingsKeys.calendarTitleMode)

    let settings = AppSettings.fromUserDefaults(defaults)
    #expect(settings.notificationEnabled == false)
    #expect(settings.eventKitEnabled == true)
    #expect(settings.calendarTitle == "MeinKalender")
    #expect(settings.leadTimesDays == [1, 7])
    #expect(settings.calendarTitleMode == .fixed)
}
