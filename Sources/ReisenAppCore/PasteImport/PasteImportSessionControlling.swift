import Foundation
import ReisenDomain

/// Session-Zustand, den die gemeinsame Paste-Import-Flow-UI braucht.
///
/// Die konkrete Session lebt in `ReisenPasteImport`; SharedUI hängt nicht an diesem Modul.
@MainActor
public protocol PasteImportSessionControlling: AnyObject {
    var isConfirmingPrivateCloudCompute: Bool { get }
    var isPresentingSheet: Bool { get }
    var runningKind: PasteImportModelKind? { get }
    var choosingResult: PasteImportRunResult? { get }
    var errorMessage: String? { get }
    var canOfferFeatureRequest: Bool { get }
    var isConfirmingFeatureRequest: Bool { get }
    var featureRequestSuccessURL: URL? { get }
    var featureRequestSubmitError: String? { get }

    func confirmPrivateCloudCompute()
    func cancelConfirmation()
    func cancelRun()
    func dismissSheet()
    func review()
    func dismissError()
    func offerFailedFeatureRequest()
    func cancelFailedFeatureRequest()
    func confirmFailedFeatureRequest()
    func dismissFeatureRequestSuccess()
    func dismissFeatureRequestSubmitError()
}
