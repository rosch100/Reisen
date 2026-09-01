import Foundation
import SwiftData

extension PersistenceBootstrap {
    static func inMemoryDualConfigurations() -> (ModelConfiguration, ModelConfiguration) {
        let cloudSchema = Schema(ReisenSchemaV10.cloudModels)
        let localSchema = Schema(ReisenSchemaV10.localModels)
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
