import SwiftUI
import ReisenDomain

public struct GapDeepLinkButtons: View {
    let links: [DeepLinkSuggestion]
    let gapKind: GapKind
    let openURL: (URL) -> Void

    public init(
        links: [DeepLinkSuggestion],
        gapKind: GapKind,
        openURL: @escaping (URL) -> Void
    ) {
        self.links = links
        self.gapKind = gapKind
        self.openURL = openURL
    }

    public var body: some View {
        ForEach(Array(ProviderDeepLinks.openableLinks(links, gapKind: gapKind).enumerated()), id: \.offset) { _, item in
            Button(item.suggestion.title) {
                openURL(item.url)
            }
        }
    }
}
