import Foundation
import Testing
import ReisenDomain
import ReisenPasteImport

@Test func pasteImportAvailability_privateCloudComputeWinsOverOnDevice() {
    let reader = FakeAvailabilityReader(privateCloudCompute: true, onDevice: true)
    #expect(PasteImportModelResolver.resolve(reader.availability()) == .privateCloudCompute)
}

@Test func pasteImportAvailability_onDeviceOnlyResolvesToOnDevice() {
    let reader = FakeAvailabilityReader(privateCloudCompute: false, onDevice: true)
    #expect(PasteImportModelResolver.resolve(reader.availability()) == .onDevice)
}

@Test func pasteImportAvailability_nothingAvailableResolvesToUnavailable() {
    let reader = FakeAvailabilityReader(privateCloudCompute: false, onDevice: false)
    #expect(PasteImportModelResolver.resolve(reader.availability()) == .unavailable)
}

@Test func pasteImportAvailability_privateCloudComputeWithoutOnDeviceStillResolvesToPCC() {
    let reader = FakeAvailabilityReader(privateCloudCompute: true, onDevice: false)
    #expect(PasteImportModelResolver.resolve(reader.availability()) == .privateCloudCompute)
}

/// Ohne Modell darf keine Quelle aufbereitet und kein Lauf gestartet werden — auch kein zweiter.
@Test(arguments: [
    PasteImportSource.text("ICE 123 am 28.08.2026"),
    PasteImportSource.image(Data([0x00, 0x01])),
    PasteImportSource.pdf(Data([0x00, 0x01])),
])
func pasteImportAvailability_unavailableKindThrowsWithoutModelRun(source: PasteImportSource) async {
    let extractor = FoundationModelsPasteImportExtractor(kind: .unavailable)
    await #expect(throws: PasteImportAdapterError.unavailable) {
        try await extractor.extract(from: source)
    }
}

private struct FakeAvailabilityReader: PasteImportAvailabilityReading {
    let privateCloudCompute: Bool
    let onDevice: Bool

    func availability() -> PasteImportModelAvailability {
        PasteImportModelAvailability(privateCloudCompute: privateCloudCompute, onDevice: onDevice)
    }
}
