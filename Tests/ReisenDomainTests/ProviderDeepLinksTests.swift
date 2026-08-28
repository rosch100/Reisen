import Testing
import Foundation
@testable import ReisenDomain

private struct StubGapBuilder: GapDeepLinkBuilding {
    let providerID: ProviderID
    let links: [DeepLinkSuggestion]

    func suggestions(for gap: GapContext) -> (links: [DeepLinkSuggestion], issues: [DeepLinkIssue]) {
        (links, [])
    }
}

@Test func gapSearchCategory_visibility_matchesGapKind() {
    #expect(GapSearchCategory.hotel.isVisible(for: .lodging))
    #expect(GapSearchCategory.activity.isVisible(for: .lodging))
    #expect(!GapSearchCategory.flight.isVisible(for: .lodging))

    #expect(GapSearchCategory.flight.isVisible(for: .transport))
    #expect(GapSearchCategory.carRental.isVisible(for: .transport))
    #expect(!GapSearchCategory.hotel.isVisible(for: .transport))

    #expect(GapSearchCategory.hotel.isVisible(for: .both))
    #expect(GapSearchCategory.flight.isVisible(for: .both))
}

@Test func deepLinkIssue_missingDestinationHint_visibleForTransportViaCarRental() {
    #expect(DeepLinkIssue.missingDestinationHint.isVisible(for: .transport))
    #expect(DeepLinkIssue.missingDestinationHint.isVisible(for: .lodging))
    #expect(!DeepLinkIssue.destinationIdNotDerivable.isVisible(for: .transport))
}

@Test func providerDeepLinks_shouldShow_usesCategoryNotTitle() {
    let hotel = DeepLinkSuggestion(
        title: "Anything",
        url: URL(string: "https://example.com/h"),
        category: .hotel,
        providerID: .check24
    )
    let flight = DeepLinkSuggestion(
        title: "Hotel suchen fake",
        url: URL(string: "https://example.com/f"),
        category: .flight,
        providerID: .check24
    )
    #expect(ProviderDeepLinks.shouldShow(hotel, gapKind: .lodging))
    #expect(!ProviderDeepLinks.shouldShow(flight, gapKind: .lodging))
    #expect(ProviderDeepLinks.shouldShow(flight, gapKind: .transport))
}

@Test func providerDeepLinks_selectedBuilders_filtersEnabledAndPreferred() {
    let check24 = StubGapBuilder(
        providerID: .check24,
        links: [DeepLinkSuggestion(category: .hotel, providerID: .check24, url: URL(string: "https://c"))]
    )
    let traveloka = StubGapBuilder(
        providerID: .traveloka,
        links: [DeepLinkSuggestion(category: .hotel, providerID: .traveloka, url: URL(string: "https://t"))]
    )
    let all: [any GapDeepLinkBuilding] = [check24, traveloka]
    let lookup: (ProviderID) -> (any GapDeepLinkBuilding)? = { id in
        all.first { $0.providerID == id }
    }

    let onlyCheck24 = ProviderDeepLinks.selectedBuilders(
        preferredProvider: nil,
        enabledProviderIDs: [.check24],
        deepLinkBuilder: lookup,
        allBuilders: all
    )
    #expect(onlyCheck24.map(\.providerID) == [.check24])

    let preferredDisabled = ProviderDeepLinks.selectedBuilders(
        preferredProvider: .traveloka,
        enabledProviderIDs: [.check24],
        deepLinkBuilder: lookup,
        allBuilders: all
    )
    #expect(preferredDisabled.map(\.providerID) == [.check24])

    let preferredEnabled = ProviderDeepLinks.selectedBuilders(
        preferredProvider: .traveloka,
        enabledProviderIDs: [.check24, .traveloka],
        deepLinkBuilder: lookup,
        allBuilders: all
    )
    #expect(preferredEnabled.map(\.providerID) == [.traveloka])
}

private struct IssueStubBuilder: GapDeepLinkBuilding {
    let providerID: ProviderID
    let kindToEmit: GapSearchCategory
    let issue: DeepLinkIssue

    func suggestions(for gap: GapContext) -> (links: [DeepLinkSuggestion], issues: [DeepLinkIssue]) {
        // Simuliert Altverhalten: Issues unabhängig von GapKind erzeugen.
        (
            [DeepLinkSuggestion(category: kindToEmit, providerID: providerID, url: URL(string: "https://x"))],
            [issue]
        )
    }
}

@Test func providerDeepLinks_suggestions_filtersLinksAndIssuesByGapKind() {
    let builder = IssueStubBuilder(
        providerID: .check24,
        kindToEmit: .flight,
        issue: .missingFromIATA
    )
    let lodging = GapContext(
        gapStart: Date(),
        gapEnd: Date().addingTimeInterval(3600),
        kind: .lodging,
        fromLocationFrom: nil,
        fromLocationTo: "Berlin",
        toLocationFrom: nil,
        toLocationTo: nil
    )
    let result = ProviderDeepLinks.suggestions(for: lodging, allBuilders: [builder])
    #expect(result.links.isEmpty)
    #expect(result.issues.isEmpty)
}
