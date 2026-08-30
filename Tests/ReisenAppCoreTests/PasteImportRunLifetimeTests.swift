import Foundation
import Testing
@testable import ReisenAppCore

@Test @MainActor
func pasteImportRunLifetime_successCompletesOnMainAndDeliversValue() async {
    let lifetime = PasteImportRunLifetime()
    let box = WaitBox()
    var received: Int?
    var completedOnMain = false

    lifetime.begin(
        work: {
            try await Task.sleep(nanoseconds: 5_000_000)
            return 42
        },
        onSuccess: { value in
            received = value
            completedOnMain = Thread.isMainThread
            box.complete()
        },
        onFailure: { _ in
            box.complete()
        }
    )

    await box.wait()
    #expect(received == 42)
    #expect(completedOnMain)
}

@Test @MainActor
func pasteImportRunLifetime_invalidateDropsStaleSuccess() async {
    let lifetime = PasteImportRunLifetime()
    var successCount = 0

    lifetime.begin(
        work: {
            try await Task.sleep(nanoseconds: 40_000_000)
            return "stale"
        },
        onSuccess: { _ in
            successCount += 1
        },
        onFailure: { _ in }
    )
    lifetime.invalidate()

    try? await Task.sleep(nanoseconds: 100_000_000)
    #expect(successCount == 0)
}

@Test @MainActor
func pasteImportRunLifetime_failureCompletesOnMain() async {
    let lifetime = PasteImportRunLifetime()
    let box = WaitBox()
    var sawFailure = false
    var completedOnMain = false

    struct SampleError: Error {}

    lifetime.begin(
        work: {
            throw SampleError()
        },
        onSuccess: { (_: Int) in
            box.complete()
        },
        onFailure: { _ in
            sawFailure = true
            completedOnMain = Thread.isMainThread
            box.complete()
        }
    )

    await box.wait()
    #expect(sawFailure)
    #expect(completedOnMain)
}

@MainActor
private final class WaitBox {
    private var continuation: CheckedContinuation<Void, Never>?
    private var done = false

    func complete() {
        if let continuation {
            self.continuation = nil
            continuation.resume()
        } else {
            done = true
        }
    }

    func wait() async {
        if done {
            done = false
            return
        }
        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }
}
