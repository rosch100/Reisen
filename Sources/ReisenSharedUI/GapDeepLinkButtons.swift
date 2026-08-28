import SwiftUI
import ReisenDomain

private enum GapSearchChrome {
    static let systemImage = "magnifyingglass"
}

/// HIG: Menü „Suchen“ nach Kategorie, Einträge pro Provider (kein Button-Raster).
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

    private var openable: [(suggestion: DeepLinkSuggestion, url: URL)] {
        ProviderDeepLinks.openableLinks(links, gapKind: gapKind)
    }

    private var categories: [GapSearchCategory] {
        var seen = Set<GapSearchCategory>()
        var ordered: [GapSearchCategory] = []
        for item in openable {
            if seen.insert(item.suggestion.category).inserted {
                ordered.append(item.suggestion.category)
            }
        }
        return ordered
    }

    public var body: some View {
        if openable.isEmpty {
            EmptyView()
        } else if categories.count == 1, openable.count == 1, let only = openable.first {
            Button {
                openURL(only.url)
            } label: {
                Label(only.suggestion.title, systemImage: GapSearchChrome.systemImage)
            }
        } else {
            Menu {
                ForEach(categories, id: \.self) { category in
                    let items = openable.filter { $0.suggestion.category == category }
                    if items.count == 1, let item = items.first {
                        Button(item.suggestion.title) {
                            openURL(item.url)
                        }
                    } else {
                        Section(category.sectionTitle) {
                            ForEach(items, id: \.suggestion.providerID) { item in
                                Button(item.suggestion.providerID.displayName) {
                                    openURL(item.url)
                                }
                            }
                        }
                    }
                }
            } label: {
                Label(L10n.string(.gapSearchMenu), systemImage: GapSearchChrome.systemImage)
            }
        }
    }
}

/// Picker: ein aktiver Gap-Such-Provider oder alle Aktiven.
public struct GapSearchProviderPicker: View {
    let enabledProviderIDs: [ProviderID]
    @Binding var preferredProviderID: ProviderID?

    public init(
        enabledProviderIDs: [ProviderID],
        preferredProviderID: Binding<ProviderID?>
    ) {
        self.enabledProviderIDs = enabledProviderIDs
        self._preferredProviderID = preferredProviderID
    }

    public var body: some View {
        if enabledProviderIDs.count > 1 {
            Picker(L10n.string(.gapSearchProviderPicker), selection: preferredBinding) {
                Text(L10n.string(.gapSearchAllEnabled)).tag(Optional<ProviderID>.none)
                Section(L10n.string(.gapSearchOneProvider)) {
                    ForEach(enabledProviderIDs, id: \.rawValue) { id in
                        Text(id.displayName).tag(Optional(id))
                    }
                }
            }
#if os(macOS)
            .pickerStyle(.menu)
#else
            .pickerStyle(.navigationLink)
#endif
        }
    }

    private var preferredBinding: Binding<ProviderID?> {
        Binding(
            get: {
                if let preferredProviderID, enabledProviderIDs.contains(preferredProviderID) {
                    return preferredProviderID
                }
                return nil
            },
            set: { preferredProviderID = $0 }
        )
    }
}

/// Picker + Such-Menü + Issue-Caption (Editor und Timeline).
public struct GapSearchControls: View {
    public enum Style {
        case form
        case compactTimeline
    }

    let enabledProviderIDs: [ProviderID]
    @Binding var preferredProviderID: ProviderID?
    let links: [DeepLinkSuggestion]
    let issues: [DeepLinkIssue]
    let gapKind: GapKind
    let style: Style
    let openURL: (URL) -> Void

    public init(
        enabledProviderIDs: [ProviderID],
        preferredProviderID: Binding<ProviderID?>,
        links: [DeepLinkSuggestion],
        issues: [DeepLinkIssue],
        gapKind: GapKind,
        style: Style = .form,
        openURL: @escaping (URL) -> Void
    ) {
        self.enabledProviderIDs = enabledProviderIDs
        self._preferredProviderID = preferredProviderID
        self.links = links
        self.issues = issues
        self.gapKind = gapKind
        self.style = style
        self.openURL = openURL
    }

    public var isEmpty: Bool {
        Self.hasContent(
            enabledProviderIDs: enabledProviderIDs,
            links: links,
            issues: issues
        ) == false
    }

    public static func hasContent(
        enabledProviderIDs: [ProviderID],
        links: [DeepLinkSuggestion],
        issues: [DeepLinkIssue]
    ) -> Bool {
        !enabledProviderIDs.isEmpty || !links.isEmpty || !issues.isEmpty
    }

    public var body: some View {
        if !isEmpty {
            picker
            buttons
            if let issuesMessage = ProviderDeepLinks.issuesMessage(issues) {
                Text(issuesMessage)
                    .font(style == .form ? .caption : .caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var picker: some View {
        GapSearchProviderPicker(
            enabledProviderIDs: enabledProviderIDs,
            preferredProviderID: $preferredProviderID
        )
        .modifier(GapSearchPickerChrome(style: style))
    }

    @ViewBuilder
    private var buttons: some View {
        switch style {
        case .form:
            GapDeepLinkButtons(links: links, gapKind: gapKind, openURL: openURL)
        case .compactTimeline:
            HStack(spacing: 12) {
                GapDeepLinkButtons(links: links, gapKind: gapKind, openURL: openURL)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }
}

private struct GapSearchPickerChrome: ViewModifier {
    let style: GapSearchControls.Style

    func body(content: Content) -> some View {
        switch style {
        case .form:
            content
        case .compactTimeline:
            content
                .labelsHidden()
                .frame(maxWidth: 220, alignment: .leading)
        }
    }
}
