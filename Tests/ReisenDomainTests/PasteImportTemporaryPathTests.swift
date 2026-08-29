import Foundation
import Testing
import ReisenDomain

@Test func pasteImportTemporaryPath_acceptsExactAndChildPaths() {
    let root = URL(fileURLWithPath: "/var/folders/xx/T", isDirectory: true)
    #expect(PasteImportTemporaryPath.contains(root, temporaryDirectory: root))
    #expect(
        PasteImportTemporaryPath.contains(
            root.appendingPathComponent("copy.pdf"),
            temporaryDirectory: root
        )
    )
}

@Test func pasteImportTemporaryPath_rejectsSiblingPrefixPaths() {
    let root = URL(fileURLWithPath: "/var/folders/xx/T", isDirectory: true)
    let sibling = URL(fileURLWithPath: "/var/folders/xx/T2/copy.pdf")
    #expect(!PasteImportTemporaryPath.contains(sibling, temporaryDirectory: root))
    #expect(
        !PasteImportTemporaryPath.contains(
            URL(fileURLWithPath: "/var/folders/xx/Other/copy.pdf"),
            temporaryDirectory: root
        )
    )
}
