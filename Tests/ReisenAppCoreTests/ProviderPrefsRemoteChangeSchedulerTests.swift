import Testing
@testable import ReisenAppCore

@MainActor
@Suite("ProviderPrefsRemoteChangeScheduler")
struct ProviderPrefsRemoteChangeSchedulerTests {
    @Test func schedule_coalescesToLatestWork() async {
        var runs: [Int] = []
        ProviderPrefsRemoteChangeScheduler.schedule { runs.append(1) }
        ProviderPrefsRemoteChangeScheduler.schedule { runs.append(2) }
        ProviderPrefsRemoteChangeScheduler.schedule { runs.append(3) }

        await Task.yield()
        await Task.yield()
        try? await Task.sleep(for: .milliseconds(20))

        #expect(runs == [3])
    }
}
