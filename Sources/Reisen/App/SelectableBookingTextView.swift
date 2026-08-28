import SwiftUI
import AppKit
import ReisenSharedUI

/// Best-Practice für "komplexe Darstellung + ein zusammenhängender Selektionsbereich" auf macOS:
/// SwiftUI `.textSelection(.enabled)` funktioniert nicht zuverlässig über mehrere `Text`-Views.
/// Ein nicht-editierbares `NSTextView` ist hier die robuste Lösung.
struct SelectableBookingTextView: NSViewRepresentable {
    let attributedString: AttributedString
    let copyText: String

    @Environment(\.stringPasteboard) private var pasteboard

    func makeNSView(context: Context) -> SelectableBookingNSTextView {
        let textView = SelectableBookingNSTextView()
        textView.configureAsReadOnlyCopyable()
        textView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        return textView
    }

    func updateNSView(_ nsView: SelectableBookingNSTextView, context: Context) {
        nsView.copyText = copyText
        nsView.copyPasteboard = pasteboard

        nsView.textStorage?.setAttributedString(NSAttributedString(attributedString))
        // Nach jedem Content-Wechsel Tab-Stops neu setzen (nicht nur bei Breitenänderung).
        nsView.invalidateTabStops()
        nsView.reapplyTabStops()
        nsView.recalculateIntrinsicHeight()
    }
}

/// Höhe/Copy von `PlainCopyableNSTextView`; nur Tab-Stops sind buchungsspezifisch.
final class SelectableBookingNSTextView: PlainCopyableNSTextView {
    private var lastRightTabStopX: CGFloat = -1

    override func layout() {
        reapplyTabStops()
        super.layout()
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
}
