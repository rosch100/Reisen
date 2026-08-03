import Foundation
import SwiftData

extension PersistenceBootstrap {
    static func openDualContainer(
        cloudKitEnabled: Bool,
        inMemory: Bool = false,
        cloudURL: URL? = nil,
        localURL: URL? = nil
    ) throws -> ModelContainer {
        let schema = currentSchema()
        let (cloudConfiguration, localConfiguration) = try dualConfigurations(
            cloudKitEnabled: cloudKitEnabled,
            inMemory: inMemory,
            cloudURL: cloudURL,
            localURL: localURL
        )
        do {
            return try ModelContainer(
                for: schema,
                configurations: [cloudConfiguration, localConfiguration]
            )
        } catch {
            throw PersistenceStoreError.storeIncompatible(String(describing: error))
        }
    }
}
