import Foundation
import SwiftData
import ReisenDomain

public enum ReisenSchemaV1: VersionedSchema {
    public static let versionIdentifier = Schema.Version(1, 0, 0)

    public static var models: [any PersistentModel.Type] {
        [
            SDTrip.self,
            SDBooking.self,
            SDCancellationDeadline.self,
            SDBookingRateDetails.self,
            SDGap.self,
            SDReminder.self,
        ]
    }
}

public enum ReisenMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] {
        [ReisenSchemaV1.self, ReisenSchemaV2.self, ReisenSchemaV3.self, ReisenSchemaV4.self, ReisenSchemaV5.self, ReisenSchemaV6.self]
    }

    public static var stages: [MigrationStage] { [] }
}

public enum ReisenSchemaV2: VersionedSchema {
    public static let versionIdentifier = Schema.Version(2, 0, 0)

    public static var models: [any PersistentModel.Type] {
        ReisenSchemaV1.models
    }
}

public enum ReisenSchemaV3: VersionedSchema {
    public static let versionIdentifier = Schema.Version(3, 0, 0)

    public static var models: [any PersistentModel.Type] {
        ReisenSchemaV1.models + [
            SDBookingPassenger.self,
            SDBaggageAllowance.self,
        ]
    }
}

public enum ReisenSchemaV4: VersionedSchema {
    public static let versionIdentifier = Schema.Version(4, 0, 0)

    public static var models: [any PersistentModel.Type] {
        ReisenSchemaV3.models + [
            SDCalendarEventLink.self,
        ]
    }
}

public enum ReisenSchemaV5: VersionedSchema {
    public static let versionIdentifier = Schema.Version(5, 0, 0)

    public static var models: [any PersistentModel.Type] {
        ReisenSchemaV4.models + [
            SDBookingRoomItem.self,
        ]
    }
}

public enum ReisenSchemaV6: VersionedSchema {
    public static let versionIdentifier = Schema.Version(6, 0, 0)

    public static var models: [any PersistentModel.Type] {
        ReisenSchemaV5.models + [
            SDCancellationDeadlineLink.self,
        ]
    }
}

public enum PersistenceStoreError: LocalizedError, Sendable {
    case containerCreationFailed(String)
    case storeIncompatible(String)

    public var errorDescription: String? {
        switch self {
        case .containerCreationFailed(let detail):
            return "SwiftData-Store konnte nicht geöffnet werden: \(detail)"
        case .storeIncompatible(let detail):
            return """
            Die lokale Datenbank ist mit dem aktuellen Schema nicht kompatibel: \(detail)

            Du kannst die lokale Datenbank zurücksetzen und anschließend erneut synchronisieren.
            """
        }
    }
}

@MainActor
public enum PersistenceBootstrap {
    public static func storeURL() throws -> URL {
        let fm = FileManager.default
        guard let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw PersistenceStoreError.containerCreationFailed("Application Support Verzeichnis fehlt.")
        }
        let base = appSupport.appendingPathComponent("Reisen", isDirectory: true)
        try fm.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("ReisenData.sqlite", isDirectory: false)
    }

    public static func makeContainer() throws -> ModelContainer {
        let schema = Schema(versionedSchema: ReisenSchemaV6.self)
        let configuration = ModelConfiguration(
            schema: schema,
            url: try storeURL()
        )
        do {
            return try ModelContainer(
                for: schema,
                migrationPlan: ReisenMigrationPlan.self,
                configurations: [configuration]
            )
        } catch {
            throw PersistenceStoreError.storeIncompatible(String(describing: error))
        }
    }

    public static func resetStoreFiles() throws {
        let url = try storeURL()
        let fm = FileManager.default
        let candidates = [
            url,
            URL(fileURLWithPath: url.path + "-shm"),
            URL(fileURLWithPath: url.path + "-wal"),
        ]
        for candidate in candidates where fm.fileExists(atPath: candidate.path) {
            try fm.removeItem(at: candidate)
        }
    }
}
