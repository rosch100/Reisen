import Foundation
import MapKit
import Testing
@testable import ReisenAppCore
import ReisenData
import ReisenDomain

@MainActor
@Suite("FlightTimeZoneAssigner")
struct FlightTimeZoneAssignerTests {
    @Test("bookings without IATA are skipped without throwing")
    func skipsMissingIATAWithoutThrowing() async throws {
        let container = try PersistenceBootstrap.makeInMemoryContainer()
        let context = container.mainContext

        let booking = SDBooking(
            providerRaw: ProviderID.opodo.rawValue,
            bookingTypeRaw: BookingType.flight.rawValue,
            title: "No IATA Flight",
            startAt: Date(timeIntervalSince1970: 1_800_000_000),
            endAt: Date(timeIntervalSince1970: 1_800_003_600),
            locationFrom: "Home City",
            locationTo: "Destination City",
            statusRaw: BookingStatus.confirmed.rawValue
        )
        context.insert(booking)
        try context.save()

        let repo = SwiftDataBookingRepository(modelContext: context)
        let assigner = FlightTimeZoneAssigner(bookingRepository: repo)
        try await assigner.assignMissingOffsets()

        let stored = try #require(try repo.fetchAll().first)
        #expect(stored.flightDepartureOffsetSeconds == nil)
        #expect(stored.flightArrivalOffsetSeconds == nil)
    }

    @Test("network and MapKit errors are treated as transient; CancellationError is not")
    func transientClassifierDistinguishesCancelFromNetwork() {
        let network = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut)
        let mapKit = NSError(domain: MKErrorDomain, code: Int(MKError.placemarkNotFound.rawValue))
        let persist = NSError(domain: NSCocoaErrorDomain, code: NSFileWriteUnknownError)

        #expect(FlightTimeZoneAssigner.isLikelyTransientResolveFailure(network))
        #expect(FlightTimeZoneAssigner.isLikelyTransientResolveFailure(mapKit))
        #expect(!FlightTimeZoneAssigner.isLikelyTransientResolveFailure(persist))
        #expect(!FlightTimeZoneAssigner.isLikelyTransientResolveFailure(CancellationError()))
    }
}
