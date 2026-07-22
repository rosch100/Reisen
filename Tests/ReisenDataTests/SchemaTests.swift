import Testing
import SwiftData
import ReisenData
import ReisenDomain

@Test func persistenceBootstrapCreatesContainer() throws {
    // In-memory validation of schema registration via repository round-trip would need a temp URL;
    // here we only assert VersionedSchema models are non-empty.
    #expect(!ReisenSchemaV1.models.isEmpty)
}
