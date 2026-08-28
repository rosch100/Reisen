import CoreGraphics
import Foundation
import ImageIO
import PDFKit
import ReisenDomain
import UniformTypeIdentifiers

/// Was ein PDF für das Modell hergibt: eingebetteter Text und/oder gerenderte Seiten.
///
/// Beides darf gesetzt sein; gescannte PDFs liefern nur Seitenbilder.
public struct PasteImportPDFContent: Equatable, Sendable {
    public var text: String?
    public var pageImages: [Data]

    public init(text: String? = nil, pageImages: [Data] = []) {
        self.text = text
        self.pageImages = pageImages
    }
}

/// PDF → Prompt-Material. Kein OCR: Seiten ohne eingebetteten Text gehen als Bild an das Modell.
public enum PasteImportPDFPreparation {
    /// Lange Kante der gerenderten Seite in Pixeln. Gescanntes bei Originalgröße ist zu grob,
    /// deutlich größer sprengt nur den Prompt.
    private static let renderedLongEdge: CGFloat = 1600

    public static func prepare(_ data: Data) throws -> PasteImportPDFContent {
        guard let document = PDFDocument(data: data), document.pageCount > 0 else {
            throw PasteImportAdapterError.unreadableSource
        }
        if let text = NonEmpty.string(document.string) {
            return PasteImportPDFContent(text: text)
        }
        return PasteImportPDFContent(pageImages: try pageImages(of: document))
    }

    private static func pageImages(of document: PDFDocument) throws -> [Data] {
        try (0..<document.pageCount).map { index in
            guard let page = document.page(at: index)?.pageRef else {
                throw PasteImportAdapterError.unreadableSource
            }
            return try PasteImportImageData.png(from: try render(page))
        }
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
