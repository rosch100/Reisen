import PhotosUI
import SwiftData
import SwiftUI

import ReisenAppCore
import ReisenDomain
import ReisenSharedUI

/// Quellen des iOS-Einstiegs: Dateiauswahl und Fotos.
enum PasteImportIOSSource {
    static func fromFile(_ url: URL) throws -> PasteImportSource {
        try PasteImportFileSource.source(from: url)
    }

    static func fromPhoto(_ item: PhotosPickerItem) async throws -> PasteImportSource {
        guard let data = try await item.loadTransferable(type: Data.self) else {
            throw PasteImportIOSSourceError.unreadableFile
        }
        return .image(data)
    }
}

extension View {
    /// Toolbar-Einstieg „Buchung einfügen…“ mit Datei- und Fotoauswahl.
    ///
    /// - Parameter entry: Reise-Kontext dieses Einstiegs; er entscheidet über die Reise neuer
    ///   Buchungen und wird beim Auslösen mitgegeben, nicht aus einem anderen Tab gelesen.
    func pasteImportToolbar(session: PasteImportIOSSession, entry: PasteImportEntry) -> some View {
        modifier(PasteImportToolbarModifier(session: session, entry: entry))
    }
}

private struct PasteImportToolbarModifier: ViewModifier {
    let session: PasteImportIOSSession
    let entry: PasteImportEntry

    @Environment(\.modelContext) private var modelContext
    @State private var isChoosingSource = false
    @State private var isImportingFile = false
    @State private var isPickingPhoto = false
    @State private var photoItem: PhotosPickerItem?

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .secondaryAction) {
                    PasteImportActionControl(kind: PasteImportModel.kind()) {
                        isChoosingSource = true
                    }
                }
            }
            .confirmationDialog(
                L10n.string(.menuPasteBooking),
                isPresented: $isChoosingSource,
                titleVisibility: .visible
            ) {
                Button(L10n.string(.menuPasteBookingFromFile)) { isImportingFile = true }
                Button(L10n.string(.menuPasteBookingFromPhoto)) { isPickingPhoto = true }
                Button(L10n.string(.commonCancel), role: .cancel) {}
            }
            .fileImporter(
                isPresented: $isImportingFile,
                allowedContentTypes: PasteImportFileSource.allowedContentTypes
            ) { result in
                startFromFile(result)
            }
            .photosPicker(isPresented: $isPickingPhoto, selection: $photoItem, matching: .images)
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                photoItem = nil
                Task { await startFromPhoto(item) }
            }
    }

    private func startFromFile(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            session.start(
                source: try PasteImportIOSSource.fromFile(url),
                entry: entry,
                in: modelContext
            )
        } catch {
            session.fail(L10n.string(.pasteImportErrorSource))
        }
    }

    private func startFromPhoto(_ item: PhotosPickerItem) async {
        do {
            let source = try await PasteImportIOSSource.fromPhoto(item)
            session.start(source: source, entry: entry, in: modelContext)
        } catch {
            session.fail(L10n.string(.pasteImportErrorSource))
        }
    }
}
