import SwiftUI
import SwiftData
import ReisenDomain
import ReisenData

struct GapEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let titleText: String
    let kind: GapKind
    let priceAmount: Double?
    let priceCurrencyCode: String?
    let onSave: (String, GapKind, Double?, String?) -> Void

    @State private var editedTitle: String
    @State private var editedKind: GapKind
    @State private var editedPriceText: String

    init(
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
        guard !trimmed.isEmpty else { return true } // Preis ist optional.
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

    var body: some View {
        VStack(spacing: 0) {
            Text("Lücke bearbeiten")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 14)

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
            .formStyle(.grouped)
            .padding(.horizontal, 8)

            Divider()

            HStack {
                Button("Abbrechen") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Sichern") {
                    let trimmed = editedPriceText.trimmingCharacters(in: .whitespacesAndNewlines)
                    let parsedPrice = trimmed.isEmpty ? nil : Self.parsePriceAmount(from: trimmed)
                    let currencyCode = priceCurrencyCode ?? "EUR"
                    onSave(editedTitle, editedKind, parsedPrice, currencyCode)
                }
                .disabled(!isValid)
                .keyboardShortcut(.defaultAction)
            }
            .padding(16)
        }
        .frame(width: 480, height: 320)
    }
}

