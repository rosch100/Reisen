import Testing
import Foundation
@testable import ReisenAppCore

@Test func diagnosticLogCompressor_roundTripsUTF8() throws {
    let raw = "line-a\nline-b\n"
    let encoded = try DiagnosticLogCompressor.zlibBase64(raw)
    #expect(!encoded.isEmpty)
    let decoded = try DiagnosticLogCompressor.decodeUTF8(fromZlibBase64: encoded)
    #expect(decoded == raw)
}

@Test func diagnosticLogCompressor_previewTakesLastLines() {
    let text = (1...20).map { "z\($0)" }.joined(separator: "\n")
    let preview = DiagnosticLogCompressor.preview(from: text, lastLineCount: 12)
    #expect(preview.split(separator: "\n").count == 12)
    #expect(preview.contains("z20"))
    #expect(!preview.contains("z1\n"))
}
