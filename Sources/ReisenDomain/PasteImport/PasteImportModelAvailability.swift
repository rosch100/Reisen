/// Verfügbarkeit der Extraktions-Modelle auf dem Gerät.
public struct PasteImportModelAvailability: Equatable, Sendable {
    public var privateCloudCompute: Bool
    public var onDevice: Bool

    public init(privateCloudCompute: Bool, onDevice: Bool) {
        self.privateCloudCompute = privateCloudCompute
        self.onDevice = onDevice
    }
}
