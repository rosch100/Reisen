import Foundation
import SwiftData
import ReisenDomain

enum SwiftDataCalendarEventLinkFind {
    static func existing(for link: CalendarEventLink, in context: ModelContext) throws -> SDCalendarEventLink? {
        let roleRaw = link.role.rawValue
        let ownerTripID = link.ownerTripID

        if let ownerBookingID = link.ownerBookingID {
            let descriptor = FetchDescriptor<SDCalendarEventLink>(
                predicate: #Predicate {
                    $0.roleRaw == roleRaw &&
                    $0.ownerTripID == ownerTripID &&
                    $0.ownerBookingID == ownerBookingID
                }
            )
            return try context.fetch(descriptor).first
        }

        let descriptor = FetchDescriptor<SDCalendarEventLink>(
            predicate: #Predicate {
                $0.roleRaw == roleRaw &&
                $0.ownerTripID == ownerTripID &&
                $0.ownerBookingID == nil
            }
        )
        return try context.fetch(descriptor).first
    }
}
