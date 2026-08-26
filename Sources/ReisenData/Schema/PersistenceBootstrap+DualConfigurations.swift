import Foundation
import SwiftData

extension PersistenceBootstrap {
    static func dualConfigurations(
        cloudKitEnabled: Bool,
        inMemory: Bool,
        cloudURL: URL?,
        localURL: URL?
    ) throws -> (ModelConfiguration, ModelConfiguration) {
        if inMemory {
            return inMemoryDualConfigurations()
        }
        return try onDiskDualConfigurations(
            cloudKitEnabled: cloudKitEnabled,
            cloudURL: cloudURL,
            localURL: localURL
        )
    }
}
