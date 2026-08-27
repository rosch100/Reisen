import SwiftUI
import ReisenDomain

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
            Link(
                didPostUpdate ? L10n.string(.githubPublicIssue) : L10n.string(.githubIssueAlreadyOpen),
                destination: url
            )
                .font(.footnote)
            if !didPostUpdate {
                Text(L10n.string(.githubNoCommentThisHour))
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
