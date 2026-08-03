import Foundation
import SwiftData

extension PersistenceBootstrap {
    static func inMemoryDualConfigurations() -> (ModelConfiguration, ModelConfiguration) {
        let cloudSchema = Schema(ReisenSchemaV7.cloudModels)
        let localSchema = Schema(ReisenSchemaV7.localModels)
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
