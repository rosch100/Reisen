import Foundation

enum GetYourGuideResearchFixture {
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
