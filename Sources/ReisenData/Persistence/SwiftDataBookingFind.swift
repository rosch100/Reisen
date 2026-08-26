import Foundation
import SwiftData

enum SwiftDataBookingFind {
    static func byID(_ id: UUID, in context: ModelContext) throws -> SDBooking? {
        let descriptor = FetchDescriptor<SDBooking>(predicate: #Predicate { $0.id == id })
        return try context.fetch(descriptor).first
    }

    static func byExternalURL(_ externalUrl: String, providerRaw: String, in context: ModelContext) throws -> SDBooking? {
        let descriptor = FetchDescriptor<SDBooking>(
            predicate: #Predicate<SDBooking> {
                $0.externalUrl == externalUrl && $0.providerRaw == providerRaw
            }
        )
        return try context.fetch(descriptor).first
    }

    static func byFingerprint(_ fingerprint: String, providerRaw: String, in context: ModelContext) throws -> SDBooking? {
        let descriptor = FetchDescriptor<SDBooking>(
            predicate: #Predicate<SDBooking> {
                $0.rawPayloadFingerprint == fingerprint && $0.providerRaw == providerRaw
            }
        )
        return try context.fetch(descriptor).first
    }
}
