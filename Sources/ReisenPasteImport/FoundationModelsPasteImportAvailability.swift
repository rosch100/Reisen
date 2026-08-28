import FoundationModels
import ReisenDomain

/// Port für die Modell-Verfügbarkeit, damit Tests und CI ohne Apple-Intelligence-Hardware auskommen.
public protocol PasteImportAvailabilityReading: Sendable {
    func availability() -> PasteImportModelAvailability
}

/// Verfügbarkeit direkt aus den Foundation Models.
///
/// Beide Stufen werden einzeln beim SDK erfragt; ein `true` ohne `.available` gibt es nicht.
/// PCC zusätzlich nur mit dem managed Entitlement `com.apple.developer.private-cloud-compute`.
public struct FoundationModelsPasteImportAvailability: PasteImportAvailabilityReading {
    private let pccEntitlementPresent: Bool
    private let privateCloudComputeDeviceAvailable: Bool
    private let onDeviceAvailable: Bool

    public init() {
        self.init(
            pccEntitlementPresent: ProcessEntitlements.contains(ProcessEntitlements.privateCloudCompute),
            privateCloudComputeDeviceAvailable: Self.deviceReportsPrivateCloudCompute(),
            onDeviceAvailable: SystemLanguageModel.default.availability == .available
        )
    }

    /// Test-Einstieg: Entitlement und Geräte-Meldung getrennt, ohne Signatur und ohne SDK-I/O.
    init(
        pccEntitlementPresent: Bool,
        privateCloudComputeDeviceAvailable: Bool,
        onDeviceAvailable: Bool
    ) {
        self.pccEntitlementPresent = pccEntitlementPresent
        self.privateCloudComputeDeviceAvailable = privateCloudComputeDeviceAvailable
        self.onDeviceAvailable = onDeviceAvailable
    }

    public func availability() -> PasteImportModelAvailability {
        PasteImportModelAvailability(
            privateCloudCompute: pccEntitlementPresent && privateCloudComputeDeviceAvailable,
            onDevice: onDeviceAvailable
        )
    }

    /// Private Cloud Compute gibt es erst ab macOS 27 / iOS 27; älter heißt „nicht verfügbar“.
    private static func deviceReportsPrivateCloudCompute() -> Bool {
        guard #available(macOS 27.0, iOS 27.0, visionOS 27.0, *) else { return false }
        return PrivateCloudComputeLanguageModel().availability == .available
    }
}
