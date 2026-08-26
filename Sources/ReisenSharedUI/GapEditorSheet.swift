import SwiftUI
import ReisenDomain
import ReisenAppCore
import ReisenProviders

public struct GapEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.providerRegistry) private var providerRegistry

    let payload: GapEditorPayload
    let onSave: (String, GapKind, Double?, String?) -> Void

    @State private var editedTitle: String
    @State private var editedKind: GapKind
    @State private var editedPriceText: String
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

    private func refreshGapDeepLinks() {
        guard let registry = providerRegistry else {
            gapDeepLinks = ([], [])
            return
        }
        gapDeepLinks = registry.gapDeepLinkSuggestions(for: payload.gapContext(kind: editedKind))
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
                Section("Anzeige") {
                    TextField("Titel", text: $editedTitle)
                    Picker("Typ", selection: $editedKind) {
                        ForEach(GapKind.allCases) { kind in
                            Text(kind.rawValue.capitalized).tag(kind)
                        }
                    }
                }

                Section("Preis (optional)") {
                    TextField("Betrag (EUR)", text: $editedPriceText)
                }

                if !gapDeepLinks.links.isEmpty || !gapDeepLinks.issues.isEmpty {
                    Section("Lücke füllen") {
                        GapDeepLinkButtons(
                            links: gapDeepLinks.links,
                            gapKind: editedKind,
                            openURL: SystemURLOpener.open
                        )
                        if let issuesMessage = ProviderDeepLinks.issuesMessage(gapDeepLinks.issues) {
                            Text(issuesMessage)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Lücke bearbeiten")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") {
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
#if os(iOS)
            .reisenSheetDetents()
#endif
        }
#if os(macOS)
        .frame(width: 480, height: 320)
#endif
    }
}
