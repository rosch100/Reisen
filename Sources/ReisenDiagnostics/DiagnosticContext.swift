import Foundation
import ReisenDomain

public struct DiagnosticContext: Codable, Equatable, Sendable {
    @TaskLocal public static var current: DiagnosticContext?

    public let runID: UUID
    public let providerID: ProviderID
    public let operation: String

    public init(runID: UUID, providerID: ProviderID, operation: String) {
        self.runID = runID
        self.providerID = providerID
        self.operation = operation
    }
}
