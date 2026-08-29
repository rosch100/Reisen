import Foundation
import ReisenDomain

public struct PasteImportFailedFeatureRequestPresentation: Equatable, Sendable {
    public let title: String
    public let message: String
    public let sendTitle: String
    public let cancelTitle: String
    public let offerTitle: String
    public let doneTitle: String
    public let mailUnavailableMessage: String

    public init() {
        title = L10n.string(.pasteImportFeatureRequestTitle)
        message = L10n.string(.pasteImportFeatureRequestMessage)
        sendTitle = L10n.string(.pasteImportFeatureRequestSend)
        cancelTitle = L10n.string(.commonCancel)
        offerTitle = L10n.string(.pasteImportFeatureRequest)
        doneTitle = L10n.string(.pasteImportFeatureRequestDone)
        mailUnavailableMessage = L10n.format(
            .pasteImportFeatureRequestMailUnavailable,
            GitHubRepository.feedbackEmail
        )
    }
}

public struct PasteImportCandidateSheetPresentation: Equatable, Sendable {
    public let continueEnabled: Bool
    public let showsFeatureRequestButton: Bool

    public init(candidateCount: Int, canOfferFeatureRequest: Bool) {
        continueEnabled = candidateCount > 0
        showsFeatureRequestButton = candidateCount == 0 && canOfferFeatureRequest
    }
}
