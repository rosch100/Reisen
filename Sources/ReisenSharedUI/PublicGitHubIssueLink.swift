import SwiftUI

public struct PublicGitHubIssueLink: View {
    public let url: URL?
    public let errorMessage: String?
    public let didPostUpdate: Bool

    public init(url: URL?, errorMessage: String?, didPostUpdate: Bool = true) {
        self.url = url
        self.errorMessage = errorMessage
        self.didPostUpdate = didPostUpdate
    }

    public var body: some View {
        if let url {
            Link(didPostUpdate ? "Öffentliches Issue" : "Issue bereits offen", destination: url)
                .font(.footnote)
            if !didPostUpdate {
                Text("Kein neues Kommentar in dieser Stunde.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } else if let errorMessage {
            Text(errorMessage)
                .font(.footnote)
                .foregroundStyle(.red)
                .textSelection(.enabled)
        }
    }
}
