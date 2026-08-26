import Foundation
import ReisenDomain

public enum ProviderDeepLinks {
    public static func suggestions(
        for gap: ComputedGap,
        preferredProvider: ProviderID?,
        deepLinkBuilder: (ProviderID) -> (any GapDeepLinkBuilding)?,
        allBuilders: [any GapDeepLinkBuilding]
    ) -> [DeepLinkSuggestion] {
        let context = GapContext(gap: gap)
        let builders: [any GapDeepLinkBuilding]

        if let preferredProvider,
           let builder = deepLinkBuilder(preferredProvider) {
            builders = [builder]
        } else {
            builders = allBuilders
        }

        return builders.flatMap { $0.suggestions(for: context).links.filter { $0.url != nil } }
    }
}
