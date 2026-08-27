import Foundation
import UserNotifications

enum UserNotificationAuthorization {
    static func mapped(_ error: Error) -> Error {
        if isNotAllowed(error) {
            return LocalReminderScheduler.SchedulerError.authorizationDenied
        }
        return error
    }

    static func isNotAllowed(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == UNErrorDomain
            && nsError.code == UNError.Code.notificationsNotAllowed.rawValue
    }

    static func isUsable(_ status: UNAuthorizationStatus) -> Bool {
        switch status {
        case .authorized, .provisional:
            return true
        #if os(iOS)
        case .ephemeral:
            return true
        #endif
        case .denied, .notDetermined:
            return false
        @unknown default:
            return false
        }
    }
}
