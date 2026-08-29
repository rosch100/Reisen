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
        let prepared = try Self.prompt(for: material)
        defer { PasteImportTemporaryPNGs.remove(prepared.temporaryImageURLs) }
        let response = try await session.respond(
            to: prepared.prompt,
            generating: PasteImportPayloadDTO.self
        )
        let mapped = PasteImportGenerableMapper.extractions(from: response.content)
        return PasteImportExtractionRefiner.refine(mapped, sourceText: material.text)
    }

    private func makeSession() throws -> LanguageModelSession {
        switch kind {
        case .unavailable:
            throw PasteImportAdapterError.unavailable
        case .onDevice:
            return LanguageModelSession(model: SystemLanguageModel.default) {
                PasteImportExtractionInstructions.text
            }
        case .privateCloudCompute:
            guard #available(macOS 27.0, iOS 27.0, visionOS 27.0, *) else {
                throw PasteImportAdapterError.unavailable
            }
            return LanguageModelSession(model: PrivateCloudComputeLanguageModel()) {
                PasteImportExtractionInstructions.text
            }
        }
    }

    private static func material(for source: PasteImportSource) throws -> PasteImportPromptMaterial {
        switch source {
        case .text(let text):
            return PasteImportPromptMaterial(text: PasteImportPromptBudget.clipped(text))
        case .image(let data):
            return PasteImportPromptMaterial(images: [data])
        case .pdf(let data):
            // `prepare` garantiert Text oder Seitenbilder, sonst wirft es `unreadableSource`.
            // Text ist bereits über `PasteImportPromptBudget` begrenzt.
            let content = try PasteImportPDFPreparation.prepare(data)
            return PasteImportPromptMaterial(text: content.text, images: content.pageImages)
        }
    }

    private static func prompt(for material: PasteImportPromptMaterial) throws -> PreparedPrompt {
        let request = request(for: material)
        guard !material.images.isEmpty else {
            return PreparedPrompt(prompt: Prompt(request), temporaryImageURLs: [])
        }
        try PasteImportImageAttachments.requireSupport()
        guard #available(macOS 27.0, iOS 27.0, visionOS 27.0, *) else {
            throw PasteImportAdapterError.imageInputUnsupported
        }
        let attachments: [Attachment<ImageAttachmentContent>]
        let temporaryImageURLs: [URL]
        if PasteImportImageAttachments.cgImageInitializerAvailable {
            attachments = try material.images.map { Attachment(try PasteImportImageData.image(from: $0)) }
            temporaryImageURLs = []
        } else {
            let urls = try PasteImportTemporaryPNGs.write(material.images)
            attachments = urls.map { Attachment(imageURL: $0) }
            temporaryImageURLs = urls
        }
        return PreparedPrompt(
            prompt: Prompt {
                request
                attachments
            },
            temporaryImageURLs: temporaryImageURLs
        )
    }

    private static func request(for material: PasteImportPromptMaterial) -> String {
        guard let text = material.text else {
            return """
                Das Material liegt als Bild vor. Lies die Buchungen daraus: Typ, Reisebeginn, Code, Orte.
                AGB ignorieren. Tour/Event = activity. Abfahrt, nicht Buchungsdatum.
                """
        }
        return """
            Material:
            \(text)
            """
    }
}

/// Was aus einer Quelle an das Modell geht: Text, Bilder oder beides.
private struct PasteImportPromptMaterial {
    var text: String?
    var images: [Data] = []
}

private struct PreparedPrompt {
    var prompt: Prompt
    var temporaryImageURLs: [URL]
}
