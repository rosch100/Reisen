import SwiftUI
import AppKit

/// Best-Practice für "komplexe Darstellung + ein zusammenhängender Selektionsbereich" auf macOS:
/// SwiftUI `.textSelection(.enabled)` funktioniert nicht zuverlässig über mehrere `Text`-Views.
/// Ein nicht-editierbares `NSTextView` ist hier die robuste Lösung.
struct SelectableBookingTextView: NSViewRepresentable {
    let attributedString: AttributedString
    let copyText: String

    func makeNSView(context: Context) -> SelectableBookingNSTextView {
        let textView = SelectableBookingNSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.backgroundColor = .clear

        textView.textContainerInset = .zero
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true

        textView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        return textView
    }

    func updateNSView(_ nsView: SelectableBookingNSTextView, context: Context) {
        nsView.copyText = copyText

        nsView.textStorage?.setAttributedString(NSAttributedString(attributedString))
        // Nach jedem Content-Wechsel Tab-Stops neu setzen (nicht nur bei Breitenänderung).
        nsView.invalidateTabStops()
        nsView.reapplyTabStops()
        nsView.recalculateIntrinsicHeight()
    }
}

final class SelectableBookingNSTextView: CopyableNSTextView {
    private var computedHeight: CGFloat = 1
    private var lastRightTabStopX: CGFloat = -1

    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: computedHeight)
    }

    override func layout() {
        super.layout()
        reapplyTabStops()
        recalculateIntrinsicHeight()
    }

    func invalidateTabStops() {
        lastRightTabStopX = -1
    }

    func reapplyTabStops() {
        let width = bounds.width
        guard width > 1 else { return }
        let rightX = max(120, width - 16)
        guard abs(rightX - lastRightTabStopX) > 0.5 else { return }
        lastRightTabStopX = rightX

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.tabStops = [NSTextTab(textAlignment: .right, location: rightX)]
        // Keine Default-Tabs dazwischen — sonst rutschen Folgezeilen nach links.
        paragraphStyle.defaultTabInterval = rightX

        let fullRange = NSRange(location: 0, length: textStorage?.length ?? 0)
        guard fullRange.length > 0 else { return }
        textStorage?.addAttribute(.paragraphStyle, value: paragraphStyle, range: fullRange)
    }

    func recalculateIntrinsicHeight() {
        guard let container = textContainer else { return }
        guard let layoutManager else { return }

        layoutManager.ensureLayout(for: container)
        let usedHeight = layoutManager.usedRect(for: container).height
        computedHeight = max(1, ceil(usedHeight))
        invalidateIntrinsicContentSize()
    }

    /// Buchungsdetails: ohne Markierung immer den bereinigten `copyText` (ohne Icon-Attachments).
    /// Mit Markierung: markierten Plain-Text (Basis-Verhalten von `CopyableNSTextView`).
    override func writeSelection(to pasteboard: NSPasteboard, types: [NSPasteboard.PasteboardType]) -> Bool {
        let range = selectedRange()
        if range.length > 0 {
            let selected = (string as NSString).substring(with: range)
            pasteboard.setString(selected, forType: .string)
            return true
        }
        guard !copyText.isEmpty else { return false }
        pasteboard.setString(copyText, forType: .string)
        return true
    }

    override func copy(_ sender: Any?) {
        let range = selectedRange()
        if range.length > 0 {
            let selected = (string as NSString).substring(with: range)
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(selected, forType: .string)
            return
        }
        guard !copyText.isEmpty else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(copyText, forType: .string)
    }
}
