import Testing
import Foundation
import SwiftData
import ReisenData
import ReisenDomain

@Test func persistenceBootstrapCreatesContainer() throws {
    #expect(!ReisenSchemaV1.models.isEmpty)
    #expect(!ReisenSchemaV9.models.isEmpty)
    #expect(ReisenMigrationPlan.schemas.contains { $0 == ReisenSchemaV9.self })
    #expect(ReisenMigrationPlan.stages.isEmpty)
    #expect(PersistenceBootstrap.cloudKitContainerID == "iCloud.de.roschmac.Reisen")
    #expect(PersistenceBootstrap.cloudStoreName == "reisen-cloud")
    #expect(PersistenceBootstrap.localStoreName == "reisen-local")
    #expect(!ReisenSchemaV9.cloudModels.isEmpty)
    #expect(!ReisenSchemaV9.localModels.isEmpty)
}

@MainActor
@Test func hybridStoreSplitKeepsCloudAndLocalModelsApart() throws {
    let cloudTypes = Set(ReisenSchemaV9.cloudModels.map { ObjectIdentifier($0) })
    let localTypes = Set(ReisenSchemaV9.localModels.map { ObjectIdentifier($0) })
    #expect(cloudTypes.isDisjoint(with: localTypes))

    #expect(cloudTypes.contains(ObjectIdentifier(SDTrip.self)))
    #expect(cloudTypes.contains(ObjectIdentifier(SDBooking.self)))
    #expect(cloudTypes.contains(ObjectIdentifier(SDGap.self)))

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
