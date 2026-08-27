import Foundation
import ReisenDomain

package enum PrivacyOptionalCapability {
    package static func deniedPane(from error: Error) -> PrivacySettingPane? {
        PrivacyAccessDenial.pane(from: UserNotificationAuthorization.mapped(error))
    }

    package static func localizedDescription(for error: Error) -> String {
        UserNotificationAuthorization.mapped(error).localizedDescription
    }

    package static func statusHint(skipped panes: [PrivacySettingPane]) -> String? {
        var seen = Set<PrivacySettingPane>()
        let unique = panes.filter { seen.insert($0).inserted }
        let labels = PrivacySettingPane.allCases
            .filter { unique.contains($0) }
            .map(\.restrictedCapabilityLabel)
        guard !labels.isEmpty else { return nil }
        return L10n.format(.privacyContinuedWithout, labels.joined(separator: ", "))
    }

    package static func statusLine(base: String, skipped panes: [PrivacySettingPane]) -> String {
        guard let hint = statusHint(skipped: panes) else { return base }
        return "\(base) \(hint)"
    }

    package static func run(_ operation: () async throws -> Void) async throws -> PrivacySettingPane? {
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
