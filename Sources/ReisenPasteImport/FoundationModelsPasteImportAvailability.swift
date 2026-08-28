import FoundationModels
import ReisenDomain

/// Port für die Modell-Verfügbarkeit, damit Tests und CI ohne Apple-Intelligence-Hardware auskommen.
public protocol PasteImportAvailabilityReading: Sendable {
    func availability() -> PasteImportModelAvailability
}

/// Verfügbarkeit direkt aus den Foundation Models.
///
/// Beide Stufen werden einzeln beim SDK erfragt; ein `true` ohne `.available` gibt es nicht.
public struct FoundationModelsPasteImportAvailability: PasteImportAvailabilityReading {
    public init() {}

    public func availability() -> PasteImportModelAvailability {
        PasteImportModelAvailability(
            privateCloudCompute: isPrivateCloudComputeAvailable,
            onDevice: SystemLanguageModel.default.availability == .available
        )
    }

    /// Private Cloud Compute gibt es erst ab macOS 27 / iOS 27; älter heißt „nicht verfügbar“.
    private var isPrivateCloudComputeAvailable: Bool {
        guard #available(macOS 27.0, iOS 27.0, visionOS 27.0, *) else { return false }
        return PrivateCloudComputeLanguageModel().availability == .available
    }
}
