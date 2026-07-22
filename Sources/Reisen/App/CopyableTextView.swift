import SwiftUI
import AppKit

/// Nicht-editierbares `NSTextView` mit CMD+C-Semantik:
/// Markierung vorhanden → markierter Text; sonst → `copyText` (Plain-Text).
class CopyableNSTextView: NSTextView {
    var copyText: String = ""

    override func writeSelection(to pasteboard: NSPasteboard, types: [NSPasteboard.PasteboardType]) -> Bool {
        let range = selectedRange()
        if range.length > 0 {
            return super.writeSelection(to: pasteboard, types: types)
        }
        guard !copyText.isEmpty else { return false }
        pasteboard.setString(copyText, forType: .string)
        return true
    }

    override func copy(_ sender: Any?) {
        let range = selectedRange()
        if range.length > 0 {
            super.copy(sender)
            return
        }
        guard !copyText.isEmpty else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(copyText, forType: .string)
    }
}

/// Plain-Text-Variante mit Intrinsic Height für SwiftUI-Layouts.
final class PlainCopyableNSTextView: CopyableNSTextView {
    private var computedHeight: CGFloat = 1

    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: computedHeight)
    }

    override func layout() {
        super.layout()
        recalculateIntrinsicHeight()
    }

    func recalculateIntrinsicHeight() {
        guard let container = textContainer else { return }
        guard let layoutManager else { return }

        layoutManager.ensureLayout(for: container)
        let usedHeight = layoutManager.usedRect(for: container).height
        let newHeight = max(1, ceil(usedHeight))
        guard abs(newHeight - computedHeight) > 0.5 else { return }
        computedHeight = newHeight
        invalidateIntrinsicContentSize()
    }
}

/// Einfacher kopierbarer Plain-Text-Block (Klick → First Responder, Selektion + CMD+C).
struct CopyableTextView: NSViewRepresentable {
    let text: String
    var copyText: String?
    var font: NSFont = .preferredFont(forTextStyle: .body)
    var textColor: NSColor = .labelColor
    var maximumNumberOfLines: Int = 0
    var lineBreakMode: NSLineBreakMode = .byWordWrapping

    func makeNSView(context: Context) -> PlainCopyableNSTextView {
        let textView = PlainCopyableNSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true
        // Horizontal darf schrumpfen (Umbruch); vertikal nicht — sonst clippt die Statusleiste.
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.setContentCompressionResistancePriority(.required, for: .vertical)
        return textView
    }

    func updateNSView(_ nsView: PlainCopyableNSTextView, context: Context) {
        nsView.copyText = copyText ?? text

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = lineBreakMode

        nsView.textContainer?.maximumNumberOfLines = maximumNumberOfLines
        nsView.textContainer?.lineBreakMode = lineBreakMode

        nsView.textStorage?.setAttributedString(
            NSAttributedString(
                string: text,
                attributes: [
                    .font: font,
                    .foregroundColor: textColor,
                    .paragraphStyle: paragraphStyle
                ]
            )
        )
        nsView.recalculateIntrinsicHeight()
    }
}

/// Icon + kopierbarer Text — visuelle Parität zu SwiftUI-`Label`, ohne Icon in der Zwischenablage.
struct CopyableLabel: View {
    let title: String
    let systemImage: String
    var textStyle: NSFont.TextStyle = .callout
    var textColor: NSColor = .labelColor
    var iconColor: Color = .primary

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: systemImage)
                .foregroundStyle(iconColor)
            CopyableTextView(
                text: title,
                font: .preferredFont(forTextStyle: textStyle),
                textColor: textColor
            )
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}
