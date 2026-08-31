import Foundation

public enum DiagnosticResult: String, Codable, Equatable, Sendable {
    case started
    case succeeded
    case failed
    case timedOut
    case cancelled
    case skipped
}

public enum DiagnosticVisibility: String, Codable, Equatable, Sendable {
    case publicDiagnostic
    case localDebugOnly
}

public struct DiagnosticEvent: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public let timestamp: Date
    public let context: DiagnosticContext
    public let component: String
    public let phase: String
    public let event: String
    public let result: DiagnosticResult
    public let attempt: Int?
    public let durationMilliseconds: Int?
    public let url: String?
    public let errorType: String?
    public let reason: String?
    public let statusBefore: String?
    public let statusAfter: String?
    public let visibility: DiagnosticVisibility

    public init(
        timestamp: Date = Date(),
        context: DiagnosticContext,
        component: String,
        phase: String,
        event: String,
        result: DiagnosticResult,
        attempt: Int? = nil,
        durationMilliseconds: Int? = nil,
        url: String? = nil,
        errorType: String? = nil,
        reason: String? = nil,
        statusBefore: String? = nil,
        statusAfter: String? = nil,
        visibility: DiagnosticVisibility = .publicDiagnostic
    ) {
        self.schemaVersion = Self.currentSchemaVersion
        self.timestamp = timestamp
        self.context = context
        self.component = component
        self.phase = phase
        self.event = event
        self.result = result
        self.attempt = attempt
        self.durationMilliseconds = durationMilliseconds
        self.url = url
        self.errorType = errorType
        self.reason = reason
        self.statusBefore = statusBefore
        self.statusAfter = statusAfter
        self.visibility = visibility
    }
}
