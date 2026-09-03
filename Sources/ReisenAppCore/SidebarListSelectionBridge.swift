import Foundation
import ReisenDomain

public enum SidebarListItemID: Hashable, Sendable {
    case provider(ProviderID)
    case openBooking(UUID)
    case elapsedBooking(UUID)
    case trip(UUID)
    case tripBooking(UUID)

    public var domain: SidebarListItemDomain {
        switch self {
        case .provider: return .provider
        case .openBooking: return .open
        case .elapsedBooking: return .elapsed
        case .trip: return .trip
        case .tripBooking: return .tripBooking
        }
    }

    public var bookingUUID: UUID? {
        switch self {
        case .openBooking(let id), .elapsedBooking(let id), .tripBooking(let id):
            return id
        case .provider, .trip:
            return nil
        }
    }

    public var tripUUID: UUID? {
        if case .trip(let id) = self { return id }
        return nil
    }

    public var providerValue: ProviderID? {
        if case .provider(let id) = self { return id }
        return nil
    }
}

public enum SidebarListItemDomain: Equatable, Sendable {
    case provider
    case open
    case elapsed
    case trip
    case tripBooking
}

public enum SidebarListMenuKind: Equatable, Sendable {
    case empty
    case mixed
    case provider
    case openBookings(count: Int)
    case elapsedBookings(count: Int)
    case trips(count: Int)
    case tripBookings(count: Int)
}

public struct SidebarListApplyResult: Equatable, Sendable {
    public var mailbox: SidebarOpenBookingMailbox?
    public var openBookingIDs: Set<UUID>
    public var tripIDs: Set<UUID>
    public var tripBookingIDs: Set<UUID>
    public var focusedTripID: UUID?
    public var providerID: ProviderID?

    public init(
        mailbox: SidebarOpenBookingMailbox? = nil,
        openBookingIDs: Set<UUID> = [],
        tripIDs: Set<UUID> = [],
        tripBookingIDs: Set<UUID> = [],
        focusedTripID: UUID? = nil,
        providerID: ProviderID? = nil
    ) {
        self.mailbox = mailbox
        self.openBookingIDs = openBookingIDs
        self.tripIDs = tripIDs
        self.tripBookingIDs = tripBookingIDs
        self.focusedTripID = focusedTripID
        self.providerID = providerID
    }
}

public enum SidebarListSelectionBridge {
    public static func listIDs(
        providerID: ProviderID?,
        mailbox: SidebarOpenBookingMailbox?,
        openBookingIDs: Set<UUID>,
        selectedTripIDs: Set<UUID>,
        tripBookingIDs: Set<UUID>
    ) -> Set<SidebarListItemID> {
        if let mailbox {
            switch mailbox {
            case .current:
                return Set(openBookingIDs.map { .openBooking($0) })
            case .elapsed:
                return Set(openBookingIDs.map { .elapsedBooking($0) })
            }
        }
        if !tripBookingIDs.isEmpty {
            return Set(tripBookingIDs.map { .tripBooking($0) })
        }
        if !selectedTripIDs.isEmpty {
            return Set(selectedTripIDs.map { .trip($0) })
        }
        if let providerID {
            return [.provider(providerID)]
        }
        return []
    }

    public static func menuKind(for ids: Set<SidebarListItemID>) -> SidebarListMenuKind {
        guard !ids.isEmpty else { return .empty }
        let domains = Set(ids.map(\.domain))
        guard domains.count == 1, let domain = domains.first else { return .mixed }
        switch domain {
        case .provider:
            return .provider
        case .open:
            return .openBookings(count: ids.count)
        case .elapsed:
            return .elapsedBookings(count: ids.count)
        case .trip:
            return .trips(count: ids.count)
        case .tripBooking:
            return .tripBookings(count: ids.count)
        }
    }

    public static func apply(
        listIDs: Set<SidebarListItemID>,
        tripIDForBooking: (UUID) -> UUID?
    ) -> SidebarListApplyResult? {
        let domains = Set(listIDs.map(\.domain))
        guard domains.count == 1, let domain = domains.first else {
            return nil
        }
        switch domain {
        case .open:
            return SidebarListApplyResult(
                mailbox: .current,
                openBookingIDs: Set(listIDs.compactMap(\.bookingUUID))
            )
        case .elapsed:
            return SidebarListApplyResult(
                mailbox: .elapsed,
                openBookingIDs: Set(listIDs.compactMap(\.bookingUUID))
            )
        case .trip:
            let tripIDs = Set(listIDs.compactMap(\.tripUUID))
            return SidebarListApplyResult(
                tripIDs: tripIDs,
                focusedTripID: tripIDs.min(by: { $0.uuidString < $1.uuidString })
            )
        case .tripBooking:
            let bookingIDs = Set(listIDs.compactMap(\.bookingUUID))
            let focused = bookingIDs
                .compactMap(tripIDForBooking)
                .min(by: { $0.uuidString < $1.uuidString })
            return SidebarListApplyResult(
                tripIDs: focused.map { [$0] } ?? [],
                tripBookingIDs: bookingIDs,
                focusedTripID: focused
            )
        case .provider:
            let provider = listIDs.compactMap(\.providerValue).min(by: { $0.rawValue < $1.rawValue })
            return SidebarListApplyResult(providerID: provider)
        }
    }
}

