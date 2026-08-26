import SwiftUI
import ReisenDomain

public struct GapEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let titleText: String
    let kind: GapKind
    let priceAmount: Double?
    let priceCurrencyCode: String?
    let onSave: (String, GapKind, Double?, String?) -> Void

    @State private var editedTitle: String
    @State private var editedKind: GapKind
    @State private var editedPriceText: String

    public init(
        titleText: String,
        kind: GapKind,
        priceAmount: Double? = nil,
        priceCurrencyCode: String? = nil,
        onSave: @escaping (String, GapKind, Double?, String?) -> Void
    ) {
        self.titleText = titleText
        self.kind = kind
        self.priceAmount = priceAmount
        self.priceCurrencyCode = priceCurrencyCode
        self.onSave = onSave

        _editedTitle = State(initialValue: titleText)
        _editedKind = State(initialValue: kind)
        _editedPriceText = State(initialValue: Self.formatPriceAmount(priceAmount))
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
            }
#if os(iOS)
            .formStyle(.grouped)
#else
            .formStyle(.grouped)
#endif
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
                        let currencyCode = priceCurrencyCode ?? "EUR"
                        onSave(editedTitle, editedKind, parsedPrice, currencyCode)
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
#if os(iOS)
            .reisenSheetDetents()
#endif
        }
#if os(macOS)
        .frame(width: 480, height: 320)
#endif
    }
}
