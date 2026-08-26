import Testing
import Foundation
@testable import ReisenAppCore

@Test func githubIssueTokenCodec_decodesXorPayload() throws {
    let key: [UInt8] = [0x11, 0x22, 0x33, 0x44]
    let plain = Array("fixture-token".utf8)
    let bytes = plain.enumerated().map { offset, byte in
        byte ^ key[offset % key.count]
    }

    let decoded = try GitHubIssueTokenCodec.decode(bytes: bytes, key: key)
    #expect(decoded == "fixture-token")
}

@Test func githubIssueTokenCodec_emptyPayloadThrowsNotEmbedded() {
    #expect(throws: GitHubIssueTokenError.notEmbedded) {
        try GitHubIssueTokenCodec.decode(bytes: [], key: [0x01])
    }
}

@Test func githubIssueTokenStubFileHasEmptyArrays() throws {
    let candidates = [
        URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Sources/ReisenAppCore/GitHubIssues/GitHubIssueToken.generated.swift.stub"),
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/ReisenAppCore/GitHubIssues/GitHubIssueToken.generated.swift.stub"),
    ]
    let text = try candidates.compactMap { try? String(contentsOf: $0, encoding: .utf8) }.first
    let stub = try #require(text)
    #expect(stub.contains("static let bytes: [UInt8] = []"))
    #expect(stub.contains("static let key: [UInt8] = []"))
    #expect(!stub.contains("0x"))
}
