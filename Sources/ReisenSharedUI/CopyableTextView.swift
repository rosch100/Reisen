#if os(macOS)
import SwiftUI
import AppKit

/// Nicht-editierbares `NSTextView` mit CMD+C-Semantik:
/// Markierung vorhanden → markierter Text; sonst → `copyText` (Plain-Text).
open class CopyableNSTextView: NSTextView {
    public var copyText: String = ""
    /// Pasteboard-Client aus SwiftUI-Environment (Cmd+C → gleiche SSOT wie Kontextmenü).
    public var copyPasteboard: StringPasteboardClient = .system

    /// Markierter Plain-Text oder `copyText`; leer → `nil`.
    public func plainTextForClipboard() -> String? {
        let range = selectedRange()
        if range.length > 0 {
            let selected = (string as NSString).substring(with: range)
            return selected.isEmpty ? nil : selected
        }
        return copyText.isEmpty ? nil : copyText
    }

    /// Drag & Drop / fremde Pasteboards: nur Plain-Text schreiben (ohne Ansage).
    override open func writeSelection(to pasteboard: NSPasteboard, types: [NSPasteboard.PasteboardType]) -> Bool {
        guard let text = plainTextForClipboard() else { return false }
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        return true
    }

    override open func copy(_ sender: Any?) {
        guard let text = plainTextForClipboard() else { return }
        CopyAccessibility.copy(text, using: copyPasteboard)
    }
}

/// Plain-Text-Variante mit Intrinsic Height für SwiftUI-Layouts.
/// `open`, damit App-Targets (z. B. SelectableBooking) Höhe + Tab-Stops erweitern können.
open class PlainCopyableNSTextView: CopyableNSTextView {
    private var computedHeight: CGFloat = 1

    override open var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: computedHeight)
    }

    override open func layout() {
        super.layout()
        recalculateIntrinsicHeight()
    }

    open func recalculateIntrinsicHeight() {
        guard let container = textContainer else { return }
        guard let layoutManager else { return }

        layoutManager.ensureLayout(for: container)
        let usedHeight = layoutManager.usedRect(for: container).height
        let newHeight = max(1, ceil(usedHeight))
        guard abs(newHeight - computedHeight) > 0.5 else { return }
        computedHeight = newHeight
        invalidateIntrinsicContentSize()
    }

    /// Gemeinsames Setup für nicht-editierbare, selektierbare Copy-Views.
    public func configureAsReadOnlyCopyable() {
        isEditable = false
        isSelectable = true
        drawsBackground = false
        backgroundColor = .clear
        textContainerInset = .zero
        textContainer?.lineFragmentPadding = 0
        textContainer?.widthTracksTextView = true
    }
}

/// Einfacher kopierbarer Plain-Text-Block (Klick → First Responder, Selektion + CMD+C).
public struct CopyableTextView: NSViewRepresentable {
    public let text: String
    public var copyText: String?
    public var font: NSFont = .preferredFont(forTextStyle: .body)
    public var textColor: NSColor = .labelColor
    public var maximumNumberOfLines: Int = 0
    public var lineBreakMode: NSLineBreakMode = .byWordWrapping

    @Environment(\.stringPasteboard) private var pasteboard

    public init(
        text: String,
        copyText: String? = nil,
        font: NSFont = .preferredFont(forTextStyle: .body),
        textColor: NSColor = .labelColor,
        maximumNumberOfLines: Int = 0,
        lineBreakMode: NSLineBreakMode = .byWordWrapping
    ) {
        self.text = text
        self.copyText = copyText
        self.font = font
        self.textColor = textColor
        self.maximumNumberOfLines = maximumNumberOfLines
        self.lineBreakMode = lineBreakMode
    }

    public func makeNSView(context: Context) -> PlainCopyableNSTextView {
        let textView = PlainCopyableNSTextView()
        textView.configureAsReadOnlyCopyable()
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.setContentCompressionResistancePriority(.required, for: .vertical)
        return textView
    }

    public func updateNSView(_ nsView: PlainCopyableNSTextView, context: Context) {
        nsView.copyText = copyText ?? text
        nsView.copyPasteboard = pasteboard

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
public struct CopyableLabel: View {
    public let title: String
    public let systemImage: String
    public var textStyle: NSFont.TextStyle = .callout
    public var textColor: NSColor = .labelColor
    public var iconColor: Color = .primary

    public init(
        title: String,
        systemImage: String,
        textStyle: NSFont.TextStyle = .callout,
        textColor: NSColor = .labelColor,
        iconColor: Color = .primary
    ) {
        self.title = title
        self.systemImage = systemImage
        self.textStyle = textStyle
        self.textColor = textColor
        self.iconColor = iconColor
    }

    public var body: some View {
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
#endif
