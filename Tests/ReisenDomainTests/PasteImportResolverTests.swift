import Testing
import ReisenDomain

@Test func pasteImportResolver_prefersPCC() {
    #expect(
        PasteImportModelResolver.resolve(.init(privateCloudCompute: true, onDevice: true)) == .privateCloudCompute
    )
}

@Test func pasteImportResolver_onDeviceWhenPCCMissing() {
    #expect(PasteImportModelResolver.resolve(.init(privateCloudCompute: false, onDevice: true)) == .onDevice)
}

@Test func pasteImportResolver_unavailableWhenNeither() {
    #expect(PasteImportModelResolver.resolve(.init(privateCloudCompute: false, onDevice: false)) == .unavailable)
}
