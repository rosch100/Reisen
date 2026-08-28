import Foundation

public enum PasteImportSourceError: Error, Equatable, Sendable {
    case empty
}

public enum PasteImportSource: Equatable, Sendable {
    case text(String)
    case image(Data)
    case pdf(Data)

    public func validated() throws -> PasteImportSource {
        switch self {
        case .text(let raw):
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { throw PasteImportSourceError.empty }
            return .text(trimmed)
        case .image(let data), .pdf(let data):
            guard !data.isEmpty else { throw PasteImportSourceError.empty }
            return self
        }
    }
}
