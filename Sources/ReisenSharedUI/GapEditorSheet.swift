import SwiftUI
import ReisenDomain
import ReisenAppCore

public struct GapEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.providerRegistry) private var providerRegistry
    @Environment(\.openURL) private var openURL

    let payload: GapEditorPayload
    let onSave: (String, GapKind, Double?, String?) -> Void

    @State private var editedTitle: String
    @State private var editedKind: GapKind
    @State private var editedPriceText: String
    @State private var preferredSearchProvider: ProviderID?
    @State private var gapDeepLinks: (links: [DeepLinkSuggestion], issues: [DeepLinkIssue]) = ([], [])

    public init(
        payload: GapEditorPayload,
        onSave: @escaping (String, GapKind, Double?, String?) -> Void
    ) {
        self.payload = payload
        self.onSave = onSave
        _editedTitle = State(initialValue: payload.title)
        _editedKind = State(initialValue: payload.kind)
        _editedPriceText = State(initialValue: Self.formatPriceAmount(payload.priceAmount))
    }

    private var enabledGapSearchProviders: [ProviderID] {
        providerRegistry?.enabledGapSearchProviderIDs() ?? []
    }

    private func refreshGapDeepLinks() {
        guard let registry = providerRegistry else {
            gapDeepLinks = ([], [])
            return
        }
        gapDeepLinks = registry.gapDeepLinkSuggestions(
            for: payload.gapContext(kind: editedKind),
            preferredProvider: preferredSearchProvider
        )
    }

    private var isValid: Bool {
        guard !editedTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        let trimmed = editedPriceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        return Self.parsePriceAmount(from: trimmed) != nil
    }

    private static func formatPriceAmount(_ amount: Double?) -> String {
        guard let amount else { return "" }
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "de_DE_POSIX")
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: amount)) ?? String(amount)
    }

    private static func parsePriceAmount(from text: String) -> Double? {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "de_DE_POSIX")
        formatter.numberStyle = .decimal
        return formatter.number(from: text)?.doubleValue
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section(L10n.string(.gapDisplay)) {
                    TextField(L10n.string(.editorTitle), text: $editedTitle)
                    Picker(L10n.string(.editorType), selection: $editedKind) {
                        ForEach(GapKind.allCases) { kind in
                            Text(L10n.gapKindDisplay(kind)).tag(kind)
                        }
                    }
                }

                Section(L10n.string(.gapPriceOptional)) {
                    TextField(L10n.string(.gapAmountEur), text: $editedPriceText)
                }

                if GapSearchControls.hasContent(
                    enabledProviderIDs: enabledGapSearchProviders,
                    links: gapDeepLinks.links,
                    issues: gapDeepLinks.issues
                ) {
                    Section(L10n.string(.gapFill)) {
                        GapSearchControls(
                            enabledProviderIDs: enabledGapSearchProviders,
                            preferredProviderID: $preferredSearchProvider,
                            links: gapDeepLinks.links,
                            issues: gapDeepLinks.issues,
                            gapKind: editedKind,
                            style: .form,
                            openURL: { openURL($0) }
                        )
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle(L10n.string(.actionEditGap))
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.string(.commonCancel)) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.string(.commonSave)) {
                        let trimmed = editedPriceText.trimmingCharacters(in: .whitespacesAndNewlines)
                        let parsedPrice = trimmed.isEmpty ? nil : Self.parsePriceAmount(from: trimmed)
                        let currencyCode = payload.priceCurrencyCode ?? "EUR"
                        onSave(editedTitle, editedKind, parsedPrice, currencyCode)
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
            .onAppear { refreshGapDeepLinks() }
            .onChange(of: editedKind) { _, _ in refreshGapDeepLinks() }
            .onChange(of: preferredSearchProvider) { _, _ in refreshGapDeepLinks() }
#if os(iOS)
            .reisenSheetDetents()
#endif
        }
#if os(macOS)
        .frame(width: 480, height: 360)
#endif
    }
}
