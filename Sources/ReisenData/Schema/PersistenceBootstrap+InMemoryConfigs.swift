import Foundation
import SwiftData

extension PersistenceBootstrap {
    static func inMemoryDualConfigurations() -> (ModelConfiguration, ModelConfiguration) {
        let cloudSchema = Schema(ReisenSchemaV9.cloudModels)
        let localSchema = Schema(ReisenSchemaV9.localModels)
        let cloud = ModelConfiguration(
            cloudStoreName,
            schema: cloudSchema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        let local = ModelConfiguration(
            localStoreName,
            schema: localSchema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        return (cloud, local)
    }
}
