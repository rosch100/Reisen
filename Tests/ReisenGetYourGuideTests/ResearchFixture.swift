import Foundation
@testable import ReisenGetYourGuide

enum GetYourGuideResearchFixture {
    static let cloudflareChallengeHTML =
        "<html><div id=\"challenge-stage\"></div><script src=\"/cdn-cgi/challenge-platform/h/b/orchestrate\"></script></html>"

    static func initialStateHTML(_ json: String) -> String {
        "<html><script>window.\(GetYourGuideInitialState.marker) = \(json)</script></html>"
    }

    static func json(named name: String) throws -> String {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("docs/fixtures/provider-research")
            .appendingPathComponent(name)
        return try String(contentsOf: url, encoding: .utf8)
    }
}
