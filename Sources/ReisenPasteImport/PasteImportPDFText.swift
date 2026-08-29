import CoreGraphics
import Foundation
import ImageIO
import PDFKit
import ReisenDomain
import UniformTypeIdentifiers

/// Was ein PDF für das Modell hergibt: eingebetteter Text und/oder gerenderte Seiten.
///
/// Beides darf gesetzt sein; gescannte PDFs liefern nur Seitenbilder. Hybrid-PDFs liefern Text
/// plus Bilder der Seiten ohne eingebetteten Text.
public struct PasteImportPDFContent: Equatable, Sendable {
    public var text: String?
    public var pageImages: [Data]
    /// `true`, wenn eingebetteter Text wegen des Prompt-Budgets gekürzt wurde.
    public var textWasTruncated: Bool

    public init(text: String? = nil, pageImages: [Data] = [], textWasTruncated: Bool = false) {
        self.text = text
        self.pageImages = pageImages
        self.textWasTruncated = textWasTruncated
    }
}

/// PDF → Prompt-Material. Kein OCR: Seiten ohne eingebetteten Text gehen als Bild an das Modell.
public enum PasteImportPDFPreparation {
    /// Lange Kante der gerenderten Seite in Pixeln. Gescanntes bei Originalgröße ist zu grob,
    /// deutlich größer sprengt nur den Prompt.
    private static let renderedLongEdge: CGFloat = 1600
    /// Maximale Anzahl gerenderter Seiten — große Scans würden sonst Speicher und Prompt sprengen.
    public static let maxRenderedPages = 8
    /// Obergrenze der PNG-Bytes aller gerenderten Seiten zusammen.
    public static let maxRenderedBytes = 12 * 1024 * 1024

    public static func prepare(_ data: Data) throws -> PasteImportPDFContent {
        guard let document = PDFDocument(data: data), document.pageCount > 0 else {
            throw PasteImportAdapterError.unreadableSource
        }
        var pageStrings: [String] = []
        var textlessIndices: [Int] = []
        for index in 0..<document.pageCount {
            if let text = NonEmpty.string(document.page(at: index)?.string) {
                pageStrings.append(text)
            } else {
                textlessIndices.append(index)
            }
        }
        let focused = PasteImportPDFPageText.focused(pageStrings)
            ?? NonEmpty.string(document.string)
        let clip = focused.map(PasteImportPromptBudget.clip)
        let images = try pageImages(of: document, indices: textlessIndices)
        guard clip != nil || !images.isEmpty else {
            throw PasteImportAdapterError.unreadableSource
        }
        return PasteImportPDFContent(
            text: clip?.text,
            pageImages: images,
            textWasTruncated: clip?.didClip == true
        )
    }

    private static func pageImages(of document: PDFDocument, indices: [Int]) throws -> [Data] {
        guard !indices.isEmpty else { return [] }
        guard indices.count <= maxRenderedPages else {
            throw PasteImportAdapterError.unreadableSource
        }
        var images: [Data] = []
        var totalBytes = 0
        for index in indices {
            guard let page = document.page(at: index)?.pageRef else {
                throw PasteImportAdapterError.unreadableSource
            }
            let png = try PasteImportImageData.png(from: try render(page))
            totalBytes += png.count
            guard totalBytes <= maxRenderedBytes else {
                throw PasteImportAdapterError.unreadableSource
            }
            images.append(png)
        }
        return images
    }

    private static func render(_ page: CGPDFPage) throws -> CGImage {
        let box = page.getBoxRect(.mediaBox)
        let isQuarterTurned = abs(page.rotationAngle) % 180 == 90
        let upright = isQuarterTurned
            ? CGSize(width: box.height, height: box.width)
            : box.size
        let longEdge = max(upright.width, upright.height)
        guard longEdge > 0 else { throw PasteImportAdapterError.unreadableSource }

        let scale = renderedLongEdge / longEdge
        let target = CGRect(
            x: 0,
            y: 0,
            width: (upright.width * scale).rounded(),
            height: (upright.height * scale).rounded()
        )
        guard let context = CGContext(
            data: nil,
            width: Int(target.width),
            height: Int(target.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else {
            throw PasteImportAdapterError.imageConversionFailed
        }

        // Papierweiß, sonst steht schwarzer Text auf schwarzem Grund.
        context.setFillColor(gray: 1, alpha: 1)
        context.fill(target)
        context.concatenate(
            page.getDrawingTransform(.mediaBox, rect: target, rotate: 0, preserveAspectRatio: true)
        )
        context.drawPDFPage(page)

        guard let image = context.makeImage() else {
            throw PasteImportAdapterError.imageConversionFailed
        }
        return image
    }
}

/// AGB-Seiten nach einem Itinerar weglassen; die einzige Seite bleibt immer.
public enum PasteImportPDFPageText {
    public static func focused(_ pages: [String]) -> String? {
        let trimmed = pages.compactMap(NonEmpty.string)
        guard !trimmed.isEmpty else { return nil }
        var kept: [String] = []
        for (index, page) in trimmed.enumerated() {
            let dropBoilerplate = index > 0
                && PasteImportBookingText.isBoilerplate(page)
                && kept.contains(where: PasteImportBookingText.looksLikeBooking)
            if dropBoilerplate { continue }
            kept.append(page)
        }
        return NonEmpty.string(kept.joined(separator: "\n"))
    }
}

/// Bild-Bytes ↔ `CGImage` an einer Stelle: PDF-Seiten und eingefügte Bilder nutzen dasselbe.
enum PasteImportImageData {
    static func png(from image: CGImage) throws -> Data {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            throw PasteImportAdapterError.imageConversionFailed
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw PasteImportAdapterError.imageConversionFailed
        }
        return data as Data
    }

    static func image(from data: Data) throws -> CGImage {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            throw PasteImportAdapterError.imageConversionFailed
        }
        return image
    }
}
