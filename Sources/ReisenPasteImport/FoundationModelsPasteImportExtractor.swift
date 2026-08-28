import Foundation
import FoundationModels
import ReisenDomain

/// Fehler des Paste-Import-Adapters. Keine stillen Ersatzwerte: jede Ursache ist unterscheidbar.
public enum PasteImportAdapterError: Error, Equatable, Sendable {
    /// Es ist kein Modell gewählt oder verfügbar; der Lauf darf nicht starten.
    case unavailable
    /// Die Quelle liefert nichts, was an ein Modell gehen könnte (z. B. PDF ohne Seiten).
    case unreadableSource
    /// Bild-Bytes und `CGImage` lassen sich nicht ineinander überführen.
    case imageConversionFailed
    /// Das laufende System kennt die Bild-Anhänge der Foundation Models noch nicht.
    case imageInputUnsupported
}

extension PasteImportAdapterError: PasteImportFailureClassifying {
    public var pasteImportFailure: PasteImportFailure {
        switch self {
        case .unavailable:
            return .modelUnavailable
        case .unreadableSource, .imageConversionFailed:
            return .source
        case .imageInputUnsupported:
            return .imageUnsupported
        }
    }
}

/// Extraktion über die Foundation Models mit genau der übergebenen Modellstufe.
///
/// Die Stufe wählt der `PasteImportModelResolver` vor dem Lauf. Ein Fehler des Modells wird
/// hier bewusst **nicht** gefangen: kein zweiter Lauf mit der anderen Stufe.
public struct FoundationModelsPasteImportExtractor: PasteImportExtracting {
    private let kind: PasteImportModelKind

    public init(kind: PasteImportModelKind) {
        self.kind = kind
    }

    public func extract(from source: PasteImportSource) async throws -> [PasteImportExtraction] {
        // Zuerst die Stufe: ohne Modell wird die Quelle gar nicht aufbereitet.
        let session = try makeSession()
        let material = try Self.material(for: try source.validated())
        let response = try await session.respond(
            to: try Self.prompt(for: material),
            generating: PasteImportPayloadDTO.self
        )
        return try PasteImportGenerableMapper.extractions(from: response.content)
    }

    private func makeSession() throws -> LanguageModelSession {
        switch kind {
        case .unavailable:
            throw PasteImportAdapterError.unavailable
        case .onDevice:
            return LanguageModelSession(model: SystemLanguageModel.default) { Self.instructions }
        case .privateCloudCompute:
            guard #available(macOS 27.0, iOS 27.0, visionOS 27.0, *) else {
                throw PasteImportAdapterError.unavailable
            }
            return LanguageModelSession(model: PrivateCloudComputeLanguageModel()) { Self.instructions }
        }
    }

    private static func material(for source: PasteImportSource) throws -> PasteImportPromptMaterial {
        switch source {
        case .text(let text):
            return PasteImportPromptMaterial(text: text)
        case .image(let data):
            return PasteImportPromptMaterial(images: [data])
        case .pdf(let data):
            // `prepare` garantiert Text oder Seitenbilder, sonst wirft es `unreadableSource`.
            let content = try PasteImportPDFPreparation.prepare(data)
            return PasteImportPromptMaterial(text: content.text, images: content.pageImages)
        }
    }

    private static func prompt(for material: PasteImportPromptMaterial) throws -> Prompt {
        let request = request(for: material)
        guard !material.images.isEmpty else { return Prompt(request) }
        guard #available(macOS 27.0, iOS 27.0, visionOS 27.0, *) else {
            throw PasteImportAdapterError.imageInputUnsupported
        }
        let attachments = try material.images.map { Attachment(try PasteImportImageData.image(from: $0)) }
        return Prompt {
            request
            attachments
        }
    }

    private static func request(for material: PasteImportPromptMaterial) -> String {
        guard let text = material.text else {
            return "Das Material liegt als Bild vor. Lies die Buchungen daraus."
        }
        return """
            Material:
            \(text)
            """
    }

    /// Die erlaubten Labels stammen aus der Domain, damit Prompt und Mapper nicht auseinanderlaufen.
    private static let instructions = """
        Du liest Reise-Bestätigungen und gibst nur zurück, was das Material belegt.

        - Nichts ergänzen, nichts schätzen, nichts aus Erfahrung ableiten.
        - Unsichere Felder weglassen statt raten.
        - Zeitpunkte als ISO8601 mit Zeitzone, z. B. 2026-08-28T10:00:00Z.
        - bookingType nur aus: \(labels(BookingType.allCases)); sonst weglassen.
        - status nur aus: \(labels(BookingStatus.allCases)); sonst weglassen.
        - travellerType nur aus: \(labels(TravellerType.allCases)).
        - boardType nur aus: \(labels(BookingBoardType.allCases)).
        - Jede Buchung im Material wird ein eigener Eintrag in bookings.
        """

    private static func labels<Label: RawRepresentable>(_ cases: [Label]) -> String
    where Label.RawValue == String {
        cases.map(\.rawValue).joined(separator: ", ")
    }
}

/// Was aus einer Quelle an das Modell geht: Text, Bilder oder beides.
private struct PasteImportPromptMaterial {
    var text: String?
    var images: [Data] = []
}
