import Foundation
import ReisenDomain
import ReisenProviders

extension Check24DeepLinkBuilder {
    func makeFlightSearchURL(fromHint: String?, toHint: String?, date: Date) throws -> URL {
        guard let fromHint else { throw DeepLinkIssue.missingFromIATA }
        guard let toHint else { throw DeepLinkIssue.missingToIATA }
        guard let fromToken = flightSearchToken(from: fromHint) else { throw DeepLinkIssue.missingFromIATA }
        guard let toToken = flightSearchToken(from: toHint) else { throw DeepLinkIssue.missingToIATA }

        let urlString =
            "https://\(Check24KundenbereichHost.flight)/search?from_0=\(fromToken)-C&to_0=\(toToken)-C&date_0=\(GapDeepLinkText.posixDay(date))&adt=1&class=EPBF"
        guard let url = URL(string: urlString) else { throw DeepLinkIssue.missingFromIATA }
        return url
    }
}
