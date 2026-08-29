import Foundation

public enum PasteImportFailedMailAttachmentFile {
    public static func writeUnique(
        data: Data,
        fileName: String,
        fileManager: FileManager = .default,
        temporaryDirectory: URL? = nil
    ) throws -> URL {
        let root = temporaryDirectory ?? fileManager.temporaryDirectory
        let directory = root.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appending(path: fileName, directoryHint: .notDirectory)
        do {
            try data.write(to: fileURL, options: .atomic)
        } catch {
            removeContainerIfPresent(of: fileURL, fileManager: fileManager)
            throw error
        }
        return fileURL
    }

    public static func removeContainer(of fileURL: URL, fileManager: FileManager = .default) throws {
        try fileManager.removeItem(at: fileURL.deletingLastPathComponent())
    }

    public static func removeContainerIfPresent(of fileURL: URL, fileManager: FileManager = .default) {
        try? removeContainer(of: fileURL, fileManager: fileManager)
    }
}
