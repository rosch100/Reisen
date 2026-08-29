import Foundation

/// PNG-Dateien für den URL-Attachment-Fallback. Entfernen nach `respond`, auch wenn das Schreiben abbricht.
enum PasteImportTemporaryPNGs {
    static func write(_ images: [Data]) throws -> [URL] {
        var urls: [URL] = []
        do {
            urls.reserveCapacity(images.count)
            for data in images {
                let url = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension("png")
                try data.write(to: url, options: .atomic)
                urls.append(url)
            }
            return urls
        } catch {
            remove(urls)
            throw error
        }
    }

    static func remove(_ urls: [URL]) {
        for url in urls {
            try? FileManager.default.removeItem(at: url)
        }
    }
}
