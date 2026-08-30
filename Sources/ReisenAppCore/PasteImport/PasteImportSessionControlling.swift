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
    var isRunning: Bool { get }
    var choosingResult: PasteImportRunResult? { get }
    var errorMessage: String? { get }
    var canOfferFeatureRequest: Bool { get }
    var isConfirmingFeatureRequest: Bool { get }
    var featureRequestSuccessURL: URL? { get }
    var featureRequestSubmitError: String? { get }
    var featureRequestMailDraft: PasteImportFailedMailDraft? { get }
    var hasPendingCandidates: Bool { get }
    /// `true`, wenn der letzte Lauf per Abbrechen beendet wurde (bis zum nächsten Start).
    var runWasCancelled: Bool { get }

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
    /// - Parameter closesSessionOnCompleted: bei `.completed` Session schließen (Mailer-Handoff);
    ///   `false`, wenn nur der Draft verworfen wird und das Issue-Link-Sheet bleiben soll.
    func finishFeatureRequestMail(
        _ finish: PasteImportFailedMailComposeFinish,
        closesSessionOnCompleted: Bool
    )
}

public extension PasteImportSessionControlling {
    func finishFeatureRequestMail(_ finish: PasteImportFailedMailComposeFinish) {
        finishFeatureRequestMail(finish, closesSessionOnCompleted: true)
    }
}
