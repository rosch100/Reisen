import Foundation
import SwiftData

extension PersistenceBootstrap {
    static func onDiskDualConfigurations(
        cloudKitEnabled: Bool,
        cloudURL: URL?,
        localURL: URL?
    ) throws -> (ModelConfiguration, ModelConfiguration) {
        let cloudSchema = Schema(ReisenSchemaV7.cloudModels)
        let localSchema = Schema(ReisenSchemaV7.localModels)
        let cloudKitDatabase: ModelConfiguration.CloudKitDatabase =
            cloudKitEnabled ? .private(cloudKitContainerID) : .none
        let cloud = ModelConfiguration(
            cloudStoreName,
            schema: cloudSchema,
            url: try cloudURL ?? cloudStoreURL(),
            cloudKitDatabase: cloudKitDatabase
        )
        let local = ModelConfiguration(
            localStoreName,
            schema: localSchema,
            url: try localURL ?? localStoreURL(),
            cloudKitDatabase: .none
        )
        return (cloud, local)
    }
}
