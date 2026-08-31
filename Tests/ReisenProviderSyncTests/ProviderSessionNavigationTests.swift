import Foundation
import Testing
import ReisenDomain
@testable import ReisenProviderSync

@Test
func probeStartTrackerCountsOnlyIdenticalURLsWithinWindow() {
    var tracker = ProbeStartTracker()
    let firstURL = URL(string: "https://example.com/account?token=one")!
    let secondURL = URL(string: "https://example.com/bookings")!
    let start = Date(timeIntervalSince1970: 1_700_000_000)

    #expect(tracker.register(providerID: .check24, url: firstURL, at: start) == 1)
    #expect(
        tracker.register(
            providerID: .check24,
            url: firstURL,
            at: start.addingTimeInterval(9)
        ) == 2
    )
    #expect(
        tracker.register(
            providerID: .check24,
            url: firstURL,
            at: start.addingTimeInterval(10.1)
        ) == 1
    )
    #expect(tracker.register(providerID: .check24, url: secondURL, at: start) == 1)
}

@Test
func probeStartTrackerResetClearsAllProviderCounts() {
    var tracker = ProbeStartTracker()
    let url = URL(string: "https://example.com/account")!
    let now = Date(timeIntervalSince1970: 1_700_000_000)

    #expect(tracker.register(providerID: .check24, url: url, at: now) == 1)
    tracker.reset()
    #expect(tracker.register(providerID: .check24, url: url, at: now) == 1)
}
