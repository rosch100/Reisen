import PhotosUI
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

import ReisenDomain
import ReisenSharedUI

/// Quellen des iOS-Einstiegs: Dateiauswahl und Fotos.
enum PasteImportIOSSource {
    static func fromFile(_ url: URL) throws -> PasteImportSource {
        // `fileImporter` liefert eine URL außerhalb der App-Sandbox; ohne Zugriff schlägt das Lesen fehl.
        let didStartAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccess { url.stopAccessingSecurityScopedResource() }
        }
        let data = try Data(contentsOf: url)
        let type = UTType(filenameExtension: url.pathExtension)
        if type?.conforms(to: .pdf) == true { return .pdf(data) }
        if type?.conforms(to: .image) == true { return .image(data) }
        guard let text = String(data: data, encoding: .utf8) else {
            throw PasteImportIOSSourceError.unreadableFile
        }
        return .text(text)
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
    func pasteImportToolbar(session: PasteImportIOSSession) -> some View {
        modifier(PasteImportToolbarModifier(session: session))
    }
}

private struct PasteImportToolbarModifier: ViewModifier {
    let session: PasteImportIOSSession

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
                allowedContentTypes: [.pdf, .image, .plainText]
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
            session.start(source: try PasteImportIOSSource.fromFile(url), in: modelContext)
        } catch {
            session.fail(L10n.string(.pasteImportErrorSource))
        }
    }

    private func startFromPhoto(_ item: PhotosPickerItem) async {
        do {
            let source = try await PasteImportIOSSource.fromPhoto(item)
            session.start(source: source, in: modelContext)
        } catch {
            session.fail(L10n.string(.pasteImportErrorSource))
        }
    }
}
