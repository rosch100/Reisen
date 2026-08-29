import SwiftUI
import ReisenAppCore
import ReisenDomain

extension View {
    /// Nimmt PDF, Bild und Text per Drag-and-Drop an — dieselben Typen wie der Dateidialog.
    public func pasteImportDropTarget(onURLs: @escaping ([URL]) -> Void) -> some View {
        modifier(PasteImportDropTargetModifier(onURLs: onURLs))
    }

    /// Fenster-Drop plus Inbox für Dock/„Öffnen mit“ (Mac und iOS).
    ///
    /// `isSessionActive`: wenn die Session wieder idle wird, werden zurückgelegte Inbox-URLs
    /// erneut angeboten (`onExternal`).
    public func pasteImportInboxAndDrop(
        isSessionActive: Bool,
        onDropped: @escaping ([URL]) -> Void,
        onExternal: @escaping () -> Void
    ) -> some View {
        modifier(
            PasteImportInboxAndDropModifier(
                isSessionActive: isSessionActive,
                onDropped: onDropped,
                onExternal: onExternal
            )
        )
    }
}

private struct PasteImportInboxAndDropModifier: ViewModifier {
    let isSessionActive: Bool
    let onDropped: ([URL]) -> Void
    let onExternal: () -> Void

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .pasteImportExternalFilesOffered)) { _ in
                onExternal()
            }
            .onAppear(perform: onExternal)
            .onChange(of: isSessionActive) { wasActive, nowActive in
                guard PasteImportDropStartResolver.shouldRetryInbox(
                    wasActive: wasActive,
                    isActive: nowActive
                ) else { return }
                onExternal()
            }
            .pasteImportDropTarget(onURLs: onDropped)
    }
}

private struct PasteImportDropTargetModifier: ViewModifier {
    let onURLs: ([URL]) -> Void
    @State private var isTargeted = false

    func body(content: Content) -> some View {
        content
            .dropDestination(for: URL.self) { urls, _ in
                let files = PasteImportFileSource.acceptedFiles(in: urls)
                guard !files.isEmpty else { return false }
                onURLs(files)
                return true
            } isTargeted: { isTargeted = $0 }
            .overlay {
                if isTargeted {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(.tint, style: StrokeStyle(lineWidth: 3, dash: [8, 6]))
                        .background(.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                        .overlay {
                            Text(L10n.string(.menuPasteBookingFromFile))
                                .font(.headline)
                                .padding(12)
                        }
                        .padding(12)
                        .allowsHitTesting(false)
                        .accessibilityAddTraits(.isStaticText)
                }
            }
    }
}
