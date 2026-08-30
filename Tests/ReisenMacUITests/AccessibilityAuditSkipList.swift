import XCTest

/// Dokumentierte Audit-Skips (Identifier + Typ + Begründung). Leer in v1.
enum AccessibilityAuditSkipList {
    struct Entry: Equatable {
        let identifier: String
        let auditType: String
        let reason: String
    }

    static let entries: [Entry] = []

    static func shouldSkip(_ issue: XCUIAccessibilityAuditIssue) -> Bool {
        let identifier = issue.element?.identifier ?? ""
        let typeName = String(describing: issue.auditType)
        return entries.contains { $0.identifier == identifier && $0.auditType == typeName }
    }
}
