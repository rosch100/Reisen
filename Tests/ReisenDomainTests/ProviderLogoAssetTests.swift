import Foundation
import Testing
import ReisenDomain

@Test func providerLogoAssets_existForEverySyncProvider() {
    let logos = repoRoot
        .appendingPathComponent("Sources/Reisen/Resources/ProviderLogos")
    for id in ProviderID.syncProviderIDs {
        let svg = logos.appendingPathComponent("\(id.rawValue).svg")
        #expect(
            FileManager.default.fileExists(atPath: svg.path),
            "Provider-Logo fehlt: \(id.rawValue).svg"
        )
    }
}

private var repoRoot: URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}
