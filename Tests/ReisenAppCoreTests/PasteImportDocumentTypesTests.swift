import Foundation
import Testing
import ReisenDomain

@Test func pasteImportDocumentTypes_macInfoPlistDeclaresAlternateViewer() throws {
    try assertPasteImportDocumentTypes(
        at: repoRoot.appendingPathComponent("Resources/Info.plist")
    )
}

@Test func pasteImportDocumentTypes_iOSStoreAndPrivateDeclareAlternateViewer() throws {
    try assertPasteImportDocumentTypes(
        at: repoRoot.appendingPathComponent("Apps/ReiseniOS/Info.plist")
    )
    try assertPasteImportDocumentTypes(
        at: repoRoot.appendingPathComponent("Apps/ReiseniOSPrivate/Info.plist")
    )
}

private var repoRoot: URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}

private func assertPasteImportDocumentTypes(at plistURL: URL) throws {
    let data = try Data(contentsOf: plistURL)
    let plist = try PropertyListSerialization.propertyList(from: data, format: nil)
    let root = try #require(plist as? [String: Any])
    let types = try #require(root["CFBundleDocumentTypes"] as? [[String: Any]])
    let match = try #require(types.first { dict in
        let identifiers = dict["LSItemContentTypes"] as? [String] ?? []
        return Set(identifiers) == Set(PasteImportFileSource.importedTypeIdentifiers)
    })
    #expect(match["CFBundleTypeRole"] as? String == "Viewer")
    #expect(match["LSHandlerRank"] as? String == "Alternate")
}
