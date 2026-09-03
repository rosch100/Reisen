import Foundation
import Testing
import SwiftData
@testable import ReisenAppCore

@MainActor
@Test
func appBootstrap_uiTesting_skipsCrashCatcherAndUsesInMemory() {
    var installCount = 0
    var flushCount = 0
    let bootstrap = AppBootstrap(
        registry: .empty,
        uiTesting: .empty,
        crashCatcherInstall: { installCount += 1 },
        crashCatcherFlush: { flushCount += 1 }
    )
    #expect(installCount == 0)
    #expect(flushCount == 0)
    guard case .ready(let container, _, _, _) = bootstrap.state else {
        Issue.record("expected ready in-memory state")
        return
    }
    #expect(!container.configurations.isEmpty)
    for configuration in container.configurations {
        #expect(configuration.isStoredInMemoryOnly)
    }
}
