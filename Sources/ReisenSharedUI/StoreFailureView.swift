import SwiftUI

/// Shared store-open failure UI (iOS + macOS) with local reset / optional Cloud wipe.
public struct StoreFailureView: View {
    public let message: String
    public let onReset: (_ wipeCloud: Bool) -> Void
    public var contentPadding: CGFloat
    public var minFrame: CGSize?

    @State private var showResetConfirmation = false
    @State private var showCloudWipeConfirmation = false

    public init(
        message: String,
        contentPadding: CGFloat = 24,
        minFrame: CGSize? = nil,
        onReset: @escaping (_ wipeCloud: Bool) -> Void
    ) {
        self.message = message
        self.contentPadding = contentPadding
        self.minFrame = minFrame
        self.onReset = onReset
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Datenbank konnte nicht geladen werden")
                .font(.title2)
            Text(message)
                .textSelection(.enabled)
                .foregroundStyle(.secondary)

            Button("Lokale Stores zurücksetzen…") {
                showResetConfirmation = true
            }
            .buttonStyle(.borderedProminent)

            Button("Auch iCloud-Daten leeren…", role: .destructive) {
                showCloudWipeConfirmation = true
            }
            .buttonStyle(.bordered)
            .confirmationDialog(
                "Lokale Stores zurücksetzen?",
                isPresented: $showResetConfirmation,
                titleVisibility: .visible
            ) {
                Button("Lokale Stores löschen", role: .destructive) {
                    onReset(false)
                }
                Button("Abbrechen", role: .cancel) {}
            } message: {
                Text("Lokale Store-Dateien werden gelöscht. Bei aktivem iCloud Sync können synchronisierte Daten erneut geladen werden.")
            }
            .confirmationDialog(
                "iCloud-Daten wirklich leeren?",
                isPresented: $showCloudWipeConfirmation,
                titleVisibility: .visible
            ) {
                Button("iCloud und lokal leeren", role: .destructive) {
                    onReset(true)
                }
                Button("Abbrechen", role: .cancel) {}
            } message: {
                Text("Lokale Stores werden neu angelegt, vorhandene iCloud-Daten importiert und anschließend geleert (inkl. Export der Löschungen).")
            }
        }
        .padding(contentPadding)
        .modifier(OptionalMinFrame(size: minFrame))
    }
}

private struct OptionalMinFrame: ViewModifier {
    let size: CGSize?

    func body(content: Content) -> some View {
        if let size {
            content.frame(minWidth: size.width, minHeight: size.height)
        } else {
            content
        }
    }
}
