import Foundation

public enum GitHubIssueAttachmentCodecError: Error, Equatable {
    case empty
    case tooLarge(maxBytes: Int)
}

public enum GitHubIssueAttachmentCodec: Sendable {
    public static let marker = "reisen-paste-import-attachment"
    public static let maxSourceBytes = 512_000
    public static let commentBodyBudget = 60_000

    public static func comments(for attachment: GitHubIssueAttachment) throws -> [String] {
        guard !attachment.data.isEmpty else { throw GitHubIssueAttachmentCodecError.empty }
        guard attachment.data.count <= maxSourceBytes else {
            throw GitHubIssueAttachmentCodecError.tooLarge(maxBytes: maxSourceBytes)
        }
        let encoded = attachment.data.base64EncodedString()
        let probe = header(
            fileName: attachment.fileName,
            mimeType: attachment.mimeType,
            part: 1,
            parts: 999
        )
        let chunkSize = commentBodyBudget - probe.count
        guard chunkSize > 0 else {
            throw GitHubIssueAttachmentCodecError.tooLarge(maxBytes: maxSourceBytes)
        }
        let parts = max(1, (encoded.count + chunkSize - 1) / chunkSize)
        var comments: [String] = []
        comments.reserveCapacity(parts)
        var start = encoded.startIndex
        var part = 1
        while start < encoded.endIndex {
            let end = encoded.index(start, offsetBy: chunkSize, limitedBy: encoded.endIndex) ?? encoded.endIndex
            let chunk = String(encoded[start..<end])
            let body = header(
                fileName: attachment.fileName,
                mimeType: attachment.mimeType,
                part: part,
                parts: parts
            ) + chunk
            comments.append(body)
            start = end
            part += 1
        }
        return comments
    }

    private static func header(fileName: String, mimeType: String, part: Int, parts: Int) -> String {
        """
        <!-- \(marker) -->
        fileName: \(fileName)
        mimeType: \(mimeType)
        encoding: base64
        part: \(part)/\(parts)

        """
    }
}
