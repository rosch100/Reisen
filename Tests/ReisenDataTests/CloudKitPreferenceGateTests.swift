import Foundation
import Testing
import ReisenData

@Test func cloudKitGate_respectsPreferenceOff() {
    let allowed = PersistenceBootstrap.isCloudKitEnabled(
        environment: [:],
        processName: "Voyenna",
        arguments: [],
        teamIdentifier: "TEAM",
        applicationIdentifier: "TEAM.app.voyenna.reisen",
        icloudContainerIdentifiers: [PersistenceBootstrap.cloudKitContainerID],
        icloudServices: ["CloudKit"],
        icloudContainerEnvironment: "Development",
        iCloudSyncPreferenceEnabled: false
    )
    #expect(allowed == false)
}

@Test func cloudKitGate_envZeroDominatesEvenIfPreferenceOn() {
    let allowed = PersistenceBootstrap.isCloudKitEnabled(
        environment: ["REISEN_CLOUDKIT": "0"],
        processName: "Voyenna",
        arguments: [],
        teamIdentifier: "TEAM",
        applicationIdentifier: "TEAM.app.voyenna.reisen",
        icloudContainerIdentifiers: [PersistenceBootstrap.cloudKitContainerID],
        icloudServices: ["CloudKit"],
        icloudContainerEnvironment: "Development",
        iCloudSyncPreferenceEnabled: true
    )
    #expect(allowed == false)
}

@Test func cloudKitGate_preferenceOnAllowsWhenEnvOk() {
    let allowed = PersistenceBootstrap.isCloudKitEnabled(
        environment: [:],
        processName: "Voyenna",
        arguments: [],
        teamIdentifier: "TEAM",
        applicationIdentifier: "TEAM.app.voyenna.reisen",
        icloudContainerIdentifiers: [PersistenceBootstrap.cloudKitContainerID],
        icloudServices: ["CloudKit"],
        icloudContainerEnvironment: "Development",
        iCloudSyncPreferenceEnabled: true
    )
    #expect(allowed == true)
}
