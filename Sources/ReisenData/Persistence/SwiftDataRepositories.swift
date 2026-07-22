import Foundation
import SwiftData
import ReisenDomain

@MainActor
public final class SwiftDataBookingRepository: BookingRepository {
    private let modelContext: ModelContext

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    public func fetchAll() throws -> [Booking] {
        try modelContext.fetch(FetchDescriptor<SDBooking>()).map(DomainMapper.booking(from:))
    }

    public func fetch(id: UUID) throws -> Booking? {
        try findBooking(id: id).map(DomainMapper.booking(from:))
    }

    public func fetch(provider: ProviderID, from startOfDay: Date) throws -> [Booking] {
        let providerRaw = provider.rawValue
        let descriptor = FetchDescriptor<SDBooking>(
            predicate: #Predicate<SDBooking> {
                $0.providerRaw == providerRaw && $0.startAt >= startOfDay
            }
        )
        return try modelContext.fetch(descriptor).map(DomainMapper.booking(from:))
    }

    public func upsert(_ booking: Booking) throws {
        let model: SDBooking
        if let existing = try findBooking(id: booking.id) {
            model = existing
        } else if let url = booking.externalUrl,
                  let existingByURL = try findBooking(externalUrl: url, providerRaw: booking.provider.rawValue) {
            model = existingByURL
        } else {
            model = SDBooking(
                id: booking.id,
                providerRaw: booking.provider.rawValue,
                bookingTypeRaw: booking.bookingType.rawValue,
                startAt: booking.startAt,
                endAt: booking.endAt,
                statusRaw: booking.status.rawValue
            )
            modelContext.insert(model)
        }

        try apply(booking, to: model)
    }

    public func delete(id: UUID) throws {
        guard let model = try findBooking(id: id) else {
            throw RepositoryError.notFound("Booking \(id)")
        }
        modelContext.delete(model)
    }

    public func deleteProviderBookings(
        provider: ProviderID,
        keepingExternalURLs: Set<String>,
        from startOfDay: Date
    ) throws {
        let providerRaw = provider.rawValue
        let descriptor = FetchDescriptor<SDBooking>(
            predicate: #Predicate<SDBooking> {
                $0.providerRaw == providerRaw && $0.startAt >= startOfDay
            }
        )
        let models = try modelContext.fetch(descriptor)
        for model in models {
            guard let url = model.externalUrl else {
                modelContext.delete(model)
                continue
            }
            if !keepingExternalURLs.contains(url) {
                modelContext.delete(model)
            }
        }
    }

    public func save() throws {
        do {
            try modelContext.save()
        } catch {
            throw RepositoryError.persistenceFailed(String(describing: error))
        }
    }

    private func findBooking(id: UUID) throws -> SDBooking? {
        let descriptor = FetchDescriptor<SDBooking>(predicate: #Predicate { $0.id == id })
        return try modelContext.fetch(descriptor).first
    }

    private func findBooking(externalUrl: String, providerRaw: String) throws -> SDBooking? {
        let descriptor = FetchDescriptor<SDBooking>(
            predicate: #Predicate<SDBooking> {
                $0.externalUrl == externalUrl && $0.providerRaw == providerRaw
            }
        )
        return try modelContext.fetch(descriptor).first
    }

    private func apply(_ booking: Booking, to model: SDBooking) throws {
        model.providerRaw = booking.provider.rawValue
        model.bookingTypeRaw = booking.bookingType.rawValue
        model.title = booking.title
        model.confirmationCode = booking.confirmationCode
        model.externalUrl = booking.externalUrl
        model.startAt = booking.startAt
        model.endAt = booking.endAt
        model.hotelOffsetSeconds = booking.hotelOffsetSeconds
        model.flightDepartureOffsetSeconds = booking.flightDepartureOffsetSeconds
        model.flightArrivalOffsetSeconds = booking.flightArrivalOffsetSeconds
        model.hotelCheckInMinutes = booking.hotelCheckInMinutes
        model.hotelCheckOutMinutes = booking.hotelCheckOutMinutes
        model.timesSourceFingerprint = booking.timesSourceFingerprint
        model.timesNormalized = booking.timesNormalized
        model.locationFrom = booking.locationFrom
        model.locationTo = booking.locationTo
        model.locationFromAddress = booking.locationFromAddress
        model.locationToAddress = booking.locationToAddress
        model.statusRaw = booking.status.rawValue
        model.lastSyncedAt = booking.lastSyncedAt
        model.rawPayloadFingerprint = booking.rawPayloadFingerprint

        for existing in model.cancellationDeadlines {
            modelContext.delete(existing)
        }
        model.cancellationDeadlines = booking.cancellationDeadlines.map { deadline in
            SDCancellationDeadline(
                id: deadline.id,
                deadlineAt: deadline.deadlineAt,
                policyText: deadline.policyText,
                isStrict: deadline.isStrict,
                isFreeCancellation: deadline.isFreeCancellation,
                hotelOffsetSeconds: deadline.hotelOffsetSeconds,
                cancellationFeeAmount: deadline.cancellationFeeAmount,
                booking: model
            )
        }

        // Replace-Strategy für Passagiere/Gepäck:
        // Flugdetails können sich ändern (z. B. Storno/Neubuchung). Deshalb ersetzen wir die gesamte Liste,
        // statt einzelne Allowances zu patchen.
        for existing in model.passengers {
            modelContext.delete(existing)
        }
        model.passengers = booking.passengers.map { passenger in
            let sdPassenger = SDBookingPassenger(
                id: passenger.id,
                booking: model,
                passengerID: passenger.bookingID,
                passengerNumber: passenger.passengerNumber,
                travellerTypeRaw: passenger.travellerType.rawValue,
                title: passenger.title,
                givenName: passenger.givenName,
                familyName: passenger.familyName,
                secondFamilyName: passenger.secondFamilyName,
                birthDate: passenger.birthDate
            )
            sdPassenger.baggageAllowances = passenger.baggageAllowances.map { allowance in
                SDBaggageAllowance(
                    id: allowance.id,
                    passenger: sdPassenger,
                    baggageTypeRaw: allowance.type.rawValue,
                    pieceCount: allowance.pieceCount,
                    weightKg: allowance.weightKg,
                    sectionID: allowance.sectionID,
                    airlineCode: allowance.airlineCode,
                    fromLabel: allowance.fromLabel,
                    toLabel: allowance.toLabel
                )
            }
            return sdPassenger
        }

        if let details = booking.rateDetails {
            if let existing = model.rateDetails {
                existing.rawDetailsFingerprint = details.rawDetailsFingerprint
                existing.totalPriceAmount = details.totalPriceAmount
                existing.totalPriceCurrency = details.totalPriceCurrency
                existing.roomCategory = details.roomCategory
                existing.boardTypeRaw = details.boardType.rawValue
                existing.includedBreakfast = details.includedBreakfast
                existing.guestCount = details.guestCount
                existing.roomCount = details.roomCount
                existing.airline = details.airline
                existing.passengerCount = details.passengerCount
                existing.baggageInfoRaw = details.baggageInfoRaw
                existing.lastParsedAt = details.lastParsedAt

                // Replace-Strategy für Zimmer-Items:
                // Zimmerdetails können sich ändern (z.B. Umsortierung/Neuverteilung) – deshalb ersetzen wir die gesamte Liste.
                for item in existing.roomItems {
                    modelContext.delete(item)
                }
                existing.roomItems = details.roomItems.map { room in
                    SDBookingRoomItem(
                        id: room.id,
                        rateDetails: existing,
                        category: room.category,
                        confirmationCode: room.confirmationCode,
                        priceAmount: room.priceAmount,
                        priceCurrency: room.priceCurrency,
                        guestSummary: room.guestSummary,
                        externalUrl: room.externalUrl,
                        sortIndex: room.sortIndex
                    )
                }
            } else {
                let sd = SDBookingRateDetails(
                    id: details.id,
                    booking: model,
                    rawDetailsFingerprint: details.rawDetailsFingerprint,
                    totalPriceAmount: details.totalPriceAmount,
                    totalPriceCurrency: details.totalPriceCurrency,
                    roomCategory: details.roomCategory,
                    boardTypeRaw: details.boardType.rawValue,
                    includedBreakfast: details.includedBreakfast,
                    guestCount: details.guestCount,
                    roomCount: details.roomCount,
                    airline: details.airline,
                    passengerCount: details.passengerCount,
                    baggageInfoRaw: details.baggageInfoRaw,
                    lastParsedAt: details.lastParsedAt
                )
                modelContext.insert(sd)
                model.rateDetails = sd

                sd.roomItems = details.roomItems.map { room in
                    SDBookingRoomItem(
                        id: room.id,
                        rateDetails: sd,
                        category: room.category,
                        confirmationCode: room.confirmationCode,
                        priceAmount: room.priceAmount,
                        priceCurrency: room.priceCurrency,
                        guestSummary: room.guestSummary,
                        externalUrl: room.externalUrl,
                        sortIndex: room.sortIndex
                    )
                }
            }
        }

        if let tripID = booking.tripID {
            let tripDescriptor = FetchDescriptor<SDTrip>(predicate: #Predicate { $0.id == tripID })
            guard let trip = try modelContext.fetch(tripDescriptor).first else {
                throw RepositoryError.notFound("Trip \(tripID)")
            }
            model.trip = trip
        } else {
            // Intentionally keep existing relationship:
            // Sync drafts don't carry trip assignment, but Upsert must not wipe it.
            // Unassignment is done explicitly via `TripRepository.assignBooking(..., toTripID: nil)`.
        }
    }
}

@MainActor
public final class SwiftDataTripRepository: TripRepository {
    private let modelContext: ModelContext

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    public func fetchAll() throws -> [Trip] {
        try modelContext.fetch(FetchDescriptor<SDTrip>()).map(DomainMapper.trip(from:))
    }

    public func fetch(id: UUID) throws -> Trip? {
        let descriptor = FetchDescriptor<SDTrip>(predicate: #Predicate { $0.id == id })
        return try modelContext.fetch(descriptor).first.map(DomainMapper.trip(from:))
    }

    public func upsert(_ trip: Trip) throws {
        let tripID = trip.id
        let descriptor = FetchDescriptor<SDTrip>(predicate: #Predicate { $0.id == tripID })
        let model: SDTrip
        if let existing = try modelContext.fetch(descriptor).first {
            model = existing
        } else {
            model = SDTrip(
                id: tripID,
                title: trip.title,
                startDate: trip.startDate,
                endDate: trip.endDate
            )
            modelContext.insert(model)
        }
        model.title = trip.title
        model.startDate = trip.startDate
        model.endDate = trip.endDate
        model.destination = trip.destination
        model.notes = trip.notes
    }

    public func delete(id: UUID) throws {
        let descriptor = FetchDescriptor<SDTrip>(predicate: #Predicate { $0.id == id })
        guard let model = try modelContext.fetch(descriptor).first else {
            throw RepositoryError.notFound("Trip \(id)")
        }
        modelContext.delete(model)
    }

    public func assignBooking(bookingID: UUID, toTripID tripID: UUID?) throws {
        let bookingDescriptor = FetchDescriptor<SDBooking>(predicate: #Predicate { $0.id == bookingID })
        guard let booking = try modelContext.fetch(bookingDescriptor).first else {
            throw RepositoryError.notFound("Booking \(bookingID)")
        }
        if let tripID {
            let tripDescriptor = FetchDescriptor<SDTrip>(predicate: #Predicate { $0.id == tripID })
            guard let trip = try modelContext.fetch(tripDescriptor).first else {
                throw RepositoryError.notFound("Trip \(tripID)")
            }
            booking.trip = trip
        } else {
            booking.trip = nil
        }
    }

    public func save() throws {
        do {
            try modelContext.save()
        } catch {
            throw RepositoryError.persistenceFailed(String(describing: error))
        }
    }
}

@MainActor
public final class SwiftDataCalendarEventLinkRepository: CalendarEventLinkRepository {
    private let modelContext: ModelContext

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    public func fetchAll() throws -> [CalendarEventLink] {
        try modelContext.fetch(FetchDescriptor<SDCalendarEventLink>()).map(DomainMapper.calendarEventLink(from:))
    }

    public func fetchLinks(forTripID tripID: UUID) throws -> [CalendarEventLink] {
        let descriptor = FetchDescriptor<SDCalendarEventLink>(
            predicate: #Predicate { $0.ownerTripID == tripID }
        )
        return try modelContext.fetch(descriptor).map(DomainMapper.calendarEventLink(from:))
    }

    public func fetchLinks(forBookingID bookingID: UUID) throws -> [CalendarEventLink] {
        let descriptor = FetchDescriptor<SDCalendarEventLink>(
            predicate: #Predicate { $0.ownerBookingID == bookingID }
        )
        return try modelContext.fetch(descriptor).map(DomainMapper.calendarEventLink(from:))
    }

    public func upsert(_ link: CalendarEventLink) throws {
        let existing = try findExistingLink(for: link)
        let model: SDCalendarEventLink

        if let existing {
            model = existing
        } else {
            model = SDCalendarEventLink(
                id: link.id,
                roleRaw: link.role.rawValue,
                ownerTripID: link.ownerTripID,
                ownerBookingID: link.ownerBookingID,
                eventIdentifier: link.eventIdentifier,
                calendarItemExternalIdentifier: link.calendarItemExternalIdentifier,
                lastSyncedAt: link.lastSyncedAt
            )
            modelContext.insert(model)
        }

        model.roleRaw = link.role.rawValue
        model.ownerTripID = link.ownerTripID
        model.ownerBookingID = link.ownerBookingID
        model.eventIdentifier = link.eventIdentifier
        model.calendarItemExternalIdentifier = link.calendarItemExternalIdentifier
        model.lastSyncedAt = link.lastSyncedAt
    }

    public func deleteLinks(forTripID tripID: UUID) throws {
        let descriptor = FetchDescriptor<SDCalendarEventLink>(
            predicate: #Predicate { $0.ownerTripID == tripID }
        )
        let models = try modelContext.fetch(descriptor)
        for model in models {
            modelContext.delete(model)
        }
    }

    public func deleteLinks(forBookingID bookingID: UUID) throws {
        let descriptor = FetchDescriptor<SDCalendarEventLink>(
            predicate: #Predicate { $0.ownerBookingID == bookingID }
        )
        let models = try modelContext.fetch(descriptor)
        for model in models {
            modelContext.delete(model)
        }
    }

    public func deleteLinks(ids: [UUID]) throws {
        guard !ids.isEmpty else { return }
        let descriptor = FetchDescriptor<SDCalendarEventLink>(
            predicate: #Predicate { ids.contains($0.id) }
        )
        let models = try modelContext.fetch(descriptor)
        for model in models {
            modelContext.delete(model)
        }
    }

    public func save() throws {
        do {
            try modelContext.save()
        } catch {
            throw RepositoryError.persistenceFailed(String(describing: error))
        }
    }

    private func findExistingLink(for link: CalendarEventLink) throws -> SDCalendarEventLink? {
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
            return try modelContext.fetch(descriptor).first
        }

        let descriptor = FetchDescriptor<SDCalendarEventLink>(
            predicate: #Predicate {
                $0.roleRaw == roleRaw &&
                $0.ownerTripID == ownerTripID &&
                $0.ownerBookingID == nil
            }
        )
        return try modelContext.fetch(descriptor).first
    }
}

@MainActor
public final class SwiftDataCancellationDeadlineLinkRepository: CancellationDeadlineLinkRepository {
    private let modelContext: ModelContext

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    public func fetchAll() throws -> [CancellationDeadlineLink] {
        try modelContext.fetch(FetchDescriptor<SDCancellationDeadlineLink>()).map(DomainMapper.cancellationDeadlineLink(from:))
    }

    public func fetchLinks(forTripID tripID: UUID) throws -> [CancellationDeadlineLink] {
        let descriptor = FetchDescriptor<SDCancellationDeadlineLink>(
            predicate: #Predicate { $0.ownerTripID == tripID }
        )
        return try modelContext.fetch(descriptor).map(DomainMapper.cancellationDeadlineLink(from:))
    }

    public func fetchLinks(forCancellationDeadlineID deadlineID: UUID) throws -> [CancellationDeadlineLink] {
        let descriptor = FetchDescriptor<SDCancellationDeadlineLink>(
            predicate: #Predicate { $0.cancellationDeadlineID == deadlineID }
        )
        return try modelContext.fetch(descriptor).map(DomainMapper.cancellationDeadlineLink(from:))
    }

    public func upsert(_ link: CancellationDeadlineLink) throws {
        let deadlineID = link.cancellationDeadlineID
        let leadDays = link.leadDays

        let descriptor = FetchDescriptor<SDCancellationDeadlineLink>(
            predicate: #Predicate {
                $0.cancellationDeadlineID == deadlineID && $0.leadDays == leadDays
            }
        )
        let existing = try modelContext.fetch(descriptor).first

        let model: SDCancellationDeadlineLink
        if let existing {
            model = existing
        } else {
            model = SDCancellationDeadlineLink(
                id: link.id,
                ownerTripID: link.ownerTripID,
                ownerBookingID: link.ownerBookingID,
                cancellationDeadlineID: link.cancellationDeadlineID,
                leadDays: link.leadDays,
                eventIdentifier: link.eventIdentifier,
                reminderIdentifier: link.reminderIdentifier,
                lastSyncedAt: link.lastSyncedAt
            )
            modelContext.insert(model)
        }

        model.ownerTripID = link.ownerTripID
        model.ownerBookingID = link.ownerBookingID
        model.eventIdentifier = link.eventIdentifier
        model.reminderIdentifier = link.reminderIdentifier
        model.lastSyncedAt = link.lastSyncedAt
    }

    public func deleteLinks(forTripID tripID: UUID) throws {
        let descriptor = FetchDescriptor<SDCancellationDeadlineLink>(
            predicate: #Predicate { $0.ownerTripID == tripID }
        )
        let models = try modelContext.fetch(descriptor)
        for model in models {
            modelContext.delete(model)
        }
    }

    public func deleteLinks(forCancellationDeadlineID deadlineID: UUID) throws {
        let descriptor = FetchDescriptor<SDCancellationDeadlineLink>(
            predicate: #Predicate { $0.cancellationDeadlineID == deadlineID }
        )
        let models = try modelContext.fetch(descriptor)
        for model in models {
            modelContext.delete(model)
        }
    }

    public func deleteLinks(ids: [UUID]) throws {
        guard !ids.isEmpty else { return }
        let descriptor = FetchDescriptor<SDCancellationDeadlineLink>(
            predicate: #Predicate { ids.contains($0.id) }
        )
        let models = try modelContext.fetch(descriptor)
        for model in models {
            modelContext.delete(model)
        }
    }

    public func save() throws {
        do {
            try modelContext.save()
        } catch {
            throw RepositoryError.persistenceFailed(String(describing: error))
        }
    }
}

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

@MainActor
public final class SwiftDataReminderRepository: ReminderRepository {
    private let modelContext: ModelContext

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    public func fetchAll() throws -> [Reminder] {
        try modelContext.fetch(FetchDescriptor<SDReminder>()).map(DomainMapper.reminder(from:))
    }

    public func insert(_ reminder: Reminder) throws {
        let model = SDReminder(
            id: reminder.id,
            fireAt: reminder.fireAt,
            targetRaw: reminder.target.rawValue,
            channelRaw: reminder.channel.rawValue,
            statusRaw: reminder.status.rawValue,
            title: reminder.title,
            notes: reminder.notes,
            externalAlarmId: reminder.externalAlarmId
        )
        if let deadlineID = reminder.cancellationDeadlineID {
            let d = FetchDescriptor<SDCancellationDeadline>(predicate: #Predicate { $0.id == deadlineID })
            guard let deadline = try modelContext.fetch(d).first else {
                throw RepositoryError.notFound("CancellationDeadline \(deadlineID)")
            }
            model.cancellationDeadline = deadline
        }
        if let gapID = reminder.gapID {
            let d = FetchDescriptor<SDGap>(predicate: #Predicate { $0.id == gapID })
            guard let gap = try modelContext.fetch(d).first else {
                throw RepositoryError.notFound("Gap \(gapID)")
            }
            model.gap = gap
        }
        modelContext.insert(model)
    }

    public func deleteByIDs(_ ids: [UUID]) throws {
        guard !ids.isEmpty else { return }
        let descriptor = FetchDescriptor<SDReminder>(
            predicate: #Predicate {
                ids.contains($0.id)
            }
        )
        let models = try modelContext.fetch(descriptor)
        for model in models {
            modelContext.delete(model)
        }
    }

    public func deleteByCancellationDeadlineIDs(_ deadlineIDs: [UUID]) throws {
        let deadlineIDSet = Set(deadlineIDs)
        guard !deadlineIDSet.isEmpty else { return }

        // SwiftData currently doesn't offer great predicate ergonomics for deleting via
        // relationship-derived UUIDs, so we fetch and filter in-memory.
        let models = try modelContext.fetch(FetchDescriptor<SDReminder>())
        for model in models {
            guard let id = model.cancellationDeadline?.id else { continue }
            if deadlineIDSet.contains(id) {
                modelContext.delete(model)
            }
        }
    }

    public func save() throws {
        do {
            try modelContext.save()
        } catch {
            throw RepositoryError.persistenceFailed(String(describing: error))
        }
    }
}

@MainActor
public final class SwiftDataCancellationDeadlineRepository: CancellationDeadlineRepository {
    private let modelContext: ModelContext

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    public func fetchAll() throws -> [CancellationDeadline] {
        try modelContext.fetch(FetchDescriptor<SDCancellationDeadline>()).map(DomainMapper.deadline(from:))
    }

    public func save() throws {
        do {
            try modelContext.save()
        } catch {
            throw RepositoryError.persistenceFailed(String(describing: error))
        }
    }
}
