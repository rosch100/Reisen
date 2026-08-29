import Foundation
import SwiftData

import ReisenAppCore
import ReisenData
import ReisenDomain
import ReisenPasteImport

/// Die gewählte Datei liegt vor, ist aber nicht als Text, Bild oder PDF lesbar.
enum PasteImportIOSSourceError: Error, Equatable, Sendable {
    case unreadableFile
}

extension PasteImportIOSSourceError: PasteImportFailureClassifying {
    var pasteImportFailure: PasteImportFailure { .source }
}

extension PasteImportSession {
    /// Lädt vorhandene Buchungen aus SwiftData und startet den gemeinsamen Session-Pfad.
    func start(source: PasteImportSource?, entry: PasteImportEntry, in modelContext: ModelContext) {
        let existing: [Booking]
        do {
            existing = try modelContext.fetch(FetchDescriptor<SDBooking>())
                .map(DomainMapper.booking(from:))
        } catch {
            fail(entry: entry, message: L10n.string(.storeLoadFailed))
            return
        }
        start(source: source, entry: entry, existing: existing)
    }
}
