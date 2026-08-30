import Foundation
import ReisenDomain

public struct BookingPortalCancelRequest: Identifiable, Equatable, Sendable {
    public var id: URL { url }
    public var providerID: ProviderID
    public var url: URL

    public init(providerID: ProviderID, url: URL) {
        self.providerID = providerID
        self.url = url
    }

    public static func handle(
        _ presentation: BookingPortalCancelPresentation,
        url: URL,
        providerID: ProviderID,
        openURL: (URL) -> Void,
        presentSheet: (BookingPortalCancelRequest) -> Void
    ) {
        switch presentation {
        case .sheet:
            presentSheet(BookingPortalCancelRequest(providerID: providerID, url: url))
        case .safari:
            openURL(url)
        case .hidden:
            break
        }
    }
}
