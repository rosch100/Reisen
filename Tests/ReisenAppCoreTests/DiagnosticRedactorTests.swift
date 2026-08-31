import Foundation
import Testing
@testable import ReisenAppCore

@Test func diagnosticRedactor_keepsOnlyHost() {
    let url = URL(string: "https://kundenbereich.check24.de/user/login.html?token=secret#password")!

    #expect(DiagnosticRedactor.urlMetadata(for: url) == "kundenbereich.check24.de")
    #expect(
        DiagnosticRedactor.urlMetadata(
            for: "https://kundenbereich.check24.de/user/login.html?token=secret#password"
        ) == "kundenbereich.check24.de"
    )
}

@Test func diagnosticRedactor_omitsBookingPaths() {
    let booking = URL(
        string: "https://kundenbereich.check24.de/kundenbereich/buchung/550e8400-e29b-41d4-a716-446655440000"
    )!
    #expect(DiagnosticRedactor.urlMetadata(for: booking) == "kundenbereich.check24.de")
    let opaque = URL(string: "https://www.opodo.de/travel/secure/a1b2c3d4e5f6789012345678abcdef01")!
    #expect(DiagnosticRedactor.urlMetadata(for: opaque) == "www.opodo.de")
    let home = URL(string: "https://www.check24.de/")!
    #expect(DiagnosticRedactor.urlMetadata(for: home) == "www.check24.de")
}

@Test func diagnosticRedactor_removesCredentialsAndEmailFromText() {
    let text = "email=gast@domain.de password=secret token=abc123"

    let redacted = DiagnosticRedactor.redact(text)

    #expect(!redacted.contains("gast@domain.de"))
    #expect(!redacted.contains("password=secret"))
    #expect(!redacted.contains("token=abc123"))
    #expect(redacted.contains("[redacted]"))
}

@Test func diagnosticRedactor_removesLabeledBookingReferences() {
    let text = "bookingNumber=ABC12345 pnr: XY-9876 confirmation code: QWER1234"

    let redacted = DiagnosticRedactor.redact(text)

    #expect(!redacted.contains("ABC12345"))
    #expect(!redacted.contains("XY-9876"))
    #expect(!redacted.contains("QWER1234"))
}
