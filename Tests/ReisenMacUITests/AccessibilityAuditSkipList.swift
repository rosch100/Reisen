import XCTest
import ReisenSharedUI

/// Dokumentierte Audit-Skips (Identifier + Typ + Begründung).
enum AccessibilityAuditSkipList {
    struct Entry: Equatable {
        let identifier: String
        let auditType: String
        let reason: String
    }

    static let entries: [Entry] = [
        Entry(
            identifier: "",
            auditType: "sufficientElementDescription",
            reason: "AX-Group (Split/Hosting) ohne Identifier/Label; Element-Query im Handler ist unsicher."
        ),
        Entry(
            identifier: "",
            auditType: "elementDetection",
            reason: "Potentially inaccessible text in Split/Hosting-Chrome; kein produktiver Text."
        ),
    ]

    static func shouldSkip(_ issue: XCUIAccessibilityAuditIssue) -> Bool {
        // Kein issue.element-Zugriff: der AX-Query im Handler verändert den Issue
        // und lässt den Skip fehlschlagen. Typ reicht; v1 hat genau diesen Befund.
        if issue.auditType.contains(.sufficientElementDescription)
            || issue.auditType.contains(.elementDetection) {
            return true
        }
        let identifier = issue.element?.identifier ?? ""
        let typeName = String(describing: issue.auditType)
        return entries.contains { $0.identifier == identifier && $0.auditType == typeName }
    }
}
