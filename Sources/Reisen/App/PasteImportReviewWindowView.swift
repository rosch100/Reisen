import SwiftData
import SwiftUI
import ReisenSharedUI
import ReisenDomain

/// Inhalt des macOS-Review-Fensters für Paste-Import.
struct PasteImportReviewWindowView: View {
    @Bindable var presenter: PasteImportReviewPresenter
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            if let payload = presenter.payload {
                PasteImportReviewSheet(
                    payload: payload,
                    onCancel: {
                        presenter.cancel()
                        dismiss()
                    },
                    onSaved: { bookingID in
                        presenter.noteSaved(bookingID: bookingID)
                        dismiss()
                    }
                )
                .id(payload.id)
            } else {
                ProgressView()
                    .frame(minWidth: 320, minHeight: 200)
            }
        }
        .onChange(of: presenter.payload?.id) { _, newID in
            if newID == nil {
                dismiss()
            }
        }
        .onDisappear {
            // Ampel-Schließen = Abbrechen (kein stilles Verwerfen ohne Queue-Advance).
            if presenter.payload != nil {
                presenter.cancel()
            }
        }
    }
}
