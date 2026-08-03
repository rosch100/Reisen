import Foundation
import SwiftData
import ReisenDomain

@MainActor
public final class SwiftDataGapRepository: GapRepository {
    private let modelContext: ModelContext

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    public func fetchAll() throws -> [Gap] {
        try modelContext.fetch(FetchDescriptor<SDGap>()).map(DomainMapper.gap(from:))
    }

    public func fetch(identityKey: String) throws -> Gap? {
        let descriptor = FetchDescriptor<SDGap>(predicate: #Predicate { $0.identityKey == identityKey })
        return try modelContext.fetch(descriptor).first.map(DomainMapper.gap(from:))
    }

    public func upsert(_ gap: Gap) throws {
        let model: SDGap
        if let key = gap.identityKey {
            let descriptor = FetchDescriptor<SDGap>(predicate: #Predicate { $0.identityKey == key })
            if let existing = try modelContext.fetch(descriptor).first {
                model = existing
            } else {
                model = SDGap(
                    id: gap.id,
                    gapStart: gap.gapStart,
                    gapEnd: gap.gapEnd,
                    kindRaw: gap.kind.rawValue,
                    identityKey: gap.identityKey
                )
                modelContext.insert(model)
            }
        } else {
            let gapID = gap.id
            let descriptor = FetchDescriptor<SDGap>(predicate: #Predicate { $0.id == gapID })
            if let existing = try modelContext.fetch(descriptor).first {
                model = existing
            } else {
                model = SDGap(
                    id: gapID,
                    gapStart: gap.gapStart,
                    gapEnd: gap.gapEnd,
                    kindRaw: gap.kind.rawValue
                )
                modelContext.insert(model)
            }
        }

        model.gapStart = gap.gapStart
        model.gapEnd = gap.gapEnd
        model.kindRaw = gap.kind.rawValue
        model.titleOverride = gap.titleOverride
        model.identityKey = gap.identityKey
        model.priceAmount = gap.priceAmount
        model.priceCurrencyCode = gap.priceCurrencyCode
        model.suggestionStateRaw = gap.suggestionStateRaw

        if let tripID = gap.tripID {
            let tripDescriptor = FetchDescriptor<SDTrip>(predicate: #Predicate { $0.id == tripID })
            guard let trip = try modelContext.fetch(tripDescriptor).first else {
                throw RepositoryError.notFound("Trip \(tripID)")
            }
            model.trip = trip
        } else {
            model.trip = nil
        }
        if let fromID = gap.fromBookingID {
            let d = FetchDescriptor<SDBooking>(predicate: #Predicate { $0.id == fromID })
            guard let booking = try modelContext.fetch(d).first else {
                throw RepositoryError.notFound("Booking \(fromID)")
            }
            model.fromBooking = booking
        } else {
            model.fromBooking = nil
        }
        if let toID = gap.toBookingID {
            let d = FetchDescriptor<SDBooking>(predicate: #Predicate { $0.id == toID })
            guard let booking = try modelContext.fetch(d).first else {
                throw RepositoryError.notFound("Booking \(toID)")
            }
            model.toBooking = booking
        } else {
            model.toBooking = nil
        }
    }

    public func delete(id: UUID) throws {
        let descriptor = FetchDescriptor<SDGap>(predicate: #Predicate { $0.id == id })
        guard let model = try modelContext.fetch(descriptor).first else {
            throw RepositoryError.notFound("Gap \(id)")
        }
        modelContext.delete(model)
    }

    public func save() throws {
        do {
            try modelContext.save()
        } catch {
            throw RepositoryError.persistenceFailed(String(describing: error))
        }
    }
}
