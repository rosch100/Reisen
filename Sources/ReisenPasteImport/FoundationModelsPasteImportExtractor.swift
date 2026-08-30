import Foundation
import FoundationModels
import ReisenDomain

/// Extraktion über die Foundation Models mit genau der übergebenen Modellstufe.
///
/// Die Stufe wählt der `PasteImportModelResolver` vor dem Lauf. Ein Fehler des Modells wird
/// hier bewusst **nicht** gefangen: kein zweiter Lauf mit der anderen Stufe.
public struct FoundationModelsPasteImportExtractor: PasteImportExtracting {
    private let kind: PasteImportModelKind

    public init(kind: PasteImportModelKind) {
        self.kind = kind
    }

    public func extract(from source: PasteImportSource) async throws -> PasteImportExtractionResult {
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
        let refined = PasteImportExtractionRefiner.refine(mapped, sourceText: material.text)
        return PasteImportExtractionResult(
            extractions: refined,
            sourceWasTruncated: material.sourceWasTruncated
        )
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
            return PasteImportPromptMaterial(clip: PasteImportPromptBudget.clip(text))
        case .image(let data):
            return PasteImportPromptMaterial(images: [data])
        case .pdf(let data):
            // `prepare` garantiert Text oder Seitenbilder, sonst wirft es `unreadableSource`.
            // Text ist bereits über `PasteImportPromptBudget` begrenzt.
            let content = try PasteImportPDFPreparation.prepare(data)
            return PasteImportPromptMaterial(pdf: content)
        }
    }

    private static func prompt(for material: PasteImportPromptMaterial) throws -> PreparedPrompt {
        let request = request(for: material)
        guard !material.images.isEmpty else {
            return PreparedPrompt(prompt: Prompt(request), temporaryImageURLs: [])
        }
        guard #available(macOS 27.0, iOS 27.0, visionOS 27.0, *) else {
            throw PasteImportAdapterError.imageInputUnsupported
        }
        let prepared = try PasteImportImagePrompt.make(request: request, images: material.images)
        return PreparedPrompt(prompt: prepared.prompt, temporaryImageURLs: prepared.temporaryImageURLs)
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
    var sourceWasTruncated: Bool = false

    init(text: String? = nil, images: [Data] = [], sourceWasTruncated: Bool = false) {
        self.text = text
        self.images = images
        self.sourceWasTruncated = sourceWasTruncated
    }

    init(clip: PasteImportPromptBudget.ClipResult, images: [Data] = []) {
        self.init(
            text: clip.text,
            images: images,
            sourceWasTruncated: clip.sourceWasTruncated
        )
    }

    init(pdf: PasteImportPDFContent) {
        self.init(
            text: pdf.text,
            images: pdf.pageImages,
            sourceWasTruncated: pdf.sourceWasTruncated
        )
    }
}

private struct PreparedPrompt {
    var prompt: Prompt
    var temporaryImageURLs: [URL]
}
