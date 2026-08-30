import XCTest
import ReisenSharedUI

/// Dokumentierte Audit-Skips (Typ + Begründung).
/// Kein `issue.element`-Zugriff: der AX-Query im Handler verändert den Issue
/// und lässt den Skip fehlschlagen; v1 matched daher nur über `auditType`.
enum AccessibilityAuditSkipList {
    struct Entry: Equatable {
        let auditType: XCUIAccessibilityAuditType
        let reason: String
    }

    static let entries: [Entry] = [
        Entry(
            auditType: .sufficientElementDescription,
            reason: "AX-Group (Split/Hosting) ohne Identifier/Label; Element-Query im Handler ist unsicher."
        ),
        Entry(
            auditType: .elementDetection,
            reason: "Potentially inaccessible text in Split/Hosting-Chrome; kein produktiver Text."
        ),
        Entry(
            auditType: .parentChild,
            reason: "SwiftUI NavigationSplitView/Hosting meldet Parent/Child-Mismatch ohne produktiven AX-Bruch (CI-Runner Xcode 27)."
        ),
    ]

    static func shouldSkip(_ issue: XCUIAccessibilityAuditIssue) -> Bool {
        entries.contains { issue.auditType.contains($0.auditType) }
    }
}
