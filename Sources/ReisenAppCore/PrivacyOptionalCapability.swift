import Foundation
import ReisenDomain

enum PrivacyOptionalCapability {
    static func deniedPane(from error: Error) -> PrivacySettingPane? {
        PrivacyAccessDenial.pane(from: UserNotificationAuthorization.mapped(error))
    }

    static func statusHint(skipped panes: [PrivacySettingPane]) -> String? {
        let labels = PrivacySettingPane.allCases
            .filter { panes.contains($0) }
            .map(\.restrictedCapabilityLabel)
        guard !labels.isEmpty else { return nil }
        return "Ohne \(labels.joined(separator: ", ")) fortgesetzt."
    }

    static func run(_ operation: () async throws -> Void) async throws -> PrivacySettingPane? {
        do {
            try await operation()
            return nil
        } catch {
            if let pane = deniedPane(from: error) {
                return pane
            }
            throw UserNotificationAuthorization.mapped(error)
        }
    }
}
