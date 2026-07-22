import AppKit
import SwiftUI

/// Vertikaler Split nur für Liste ↔ Detail.
///
/// Divider-Resize läuft in AppKit (Frame-Layout), ohne SwiftUI-Body-Rebuilds während des
/// Ziehens — das verhindert Flackern. `bottomHeight` wird erst beim Loslassen persistiert.
struct PersistentVerticalSplitView<Top: View, Bottom: View>: NSViewRepresentable {
    @Binding var isBottomVisible: Bool
    @Binding var bottomHeight: Double
    /// Ideal-/Inhaltshöhe der Detailansicht; Slider darf darüber nicht hinaus (kein Leerraum).
    var bottomContentHeight: CGFloat = 0
    var topMinHeight: CGFloat = 120
    var bottomMinHeight: CGFloat = 140
    @ViewBuilder var top: () -> Top
    @ViewBuilder var bottom: () -> Bottom

    func makeCoordinator() -> VerticalSplitCoordinator {
        VerticalSplitCoordinator(
            isBottomVisible: $isBottomVisible,
            bottomHeight: $bottomHeight
        )
    }

    func makeNSView(context: Context) -> VerticalSplitNSView {
        let view = VerticalSplitNSView(
            topMinHeight: topMinHeight,
            bottomMinHeight: bottomMinHeight
        )
        view.coordinator = context.coordinator
        view.bottomContentHeight = bottomContentHeight
        view.setBottomVisible(isBottomVisible)
        view.setBottomHeight(CGFloat(bottomHeight), commit: false)
        view.updateContent(top: top(), bottom: bottom())
        return view
    }

    func updateNSView(_ view: VerticalSplitNSView, context: Context) {
        context.coordinator.isBottomVisible = $isBottomVisible
        context.coordinator.bottomHeight = $bottomHeight
        view.coordinator = context.coordinator
        view.topMinHeight = topMinHeight
        view.bottomMinHeight = bottomMinHeight
        view.bottomContentHeight = bottomContentHeight

        // Während Drag keine SwiftUI-getriebenen Größen-/Content-Updates → kein Flackern.
        guard !context.coordinator.isDragging else {
            // Content-Max während Drag trotzdem aktualisieren (Clamp).
            view.needsLayout = true
            return
        }

        view.updateContent(top: top(), bottom: bottom())
        view.setBottomHeight(CGFloat(bottomHeight), commit: false)
        view.setBottomVisible(isBottomVisible)
    }
}

final class VerticalSplitCoordinator {
    var isBottomVisible: Binding<Bool>
    var bottomHeight: Binding<Double>
    var isDragging = false

    init(isBottomVisible: Binding<Bool>, bottomHeight: Binding<Double>) {
        self.isBottomVisible = isBottomVisible
        self.bottomHeight = bottomHeight
    }

    func commitHeight(_ height: CGFloat) {
        let value = Double(height)
        if abs(bottomHeight.wrappedValue - value) > 0.5 {
            bottomHeight.wrappedValue = value
        }
    }
}

final class VerticalSplitNSView: NSView {
    var topMinHeight: CGFloat
    var bottomMinHeight: CGFloat
    /// Gemessene Inhaltshöhe; 0 = noch unbekannt → nur Layout-Max verwenden.
    var bottomContentHeight: CGFloat = 0 {
        didSet {
            if abs(oldValue - bottomContentHeight) > 0.5 {
                let clamped = clampBottomHeight(bottomHeight)
                if abs(clamped - bottomHeight) > 0.5 {
                    bottomHeight = clamped
                    coordinator?.commitHeight(clamped)
                }
                needsLayout = true
            }
        }
    }
    weak var coordinator: VerticalSplitCoordinator?

    private let topHost = NSHostingView(rootView: AnyView(EmptyView()))
    private let bottomHost = NSHostingView(rootView: AnyView(EmptyView()))
    private let divider = SplitDividerView()

    private var bottomHeight: CGFloat = 220
    private var isBottomVisible = true
    private var dragStartHeight: CGFloat = 220
    private var dragStartY: CGFloat = 0

    /// Keine Intrinsic-Höhe — sonst wächst die View mit dem Detailinhalt über das Layout hinaus.
    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: NSView.noIntrinsicMetric)
    }

    init(topMinHeight: CGFloat, bottomMinHeight: CGFloat) {
        self.topMinHeight = topMinHeight
        self.bottomMinHeight = bottomMinHeight
        super.init(frame: .zero)

        wantsLayer = true
        clipsToBounds = true
        topHost.sizingOptions = []
        bottomHost.sizingOptions = []
        topHost.clipsToBounds = true
        bottomHost.clipsToBounds = true

        for host in [topHost, bottomHost] {
            host.setContentHuggingPriority(.defaultLow, for: .vertical)
            host.setContentHuggingPriority(.defaultLow, for: .horizontal)
            host.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
            host.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        }

        addSubview(topHost)
        addSubview(divider)
        addSubview(bottomHost)

        divider.onMouseDown = { [weak self] locationInWindow in
            self?.beginDrag(locationInWindow: locationInWindow)
        }
        divider.onMouseDragged = { [weak self] locationInWindow in
            self?.continueDrag(locationInWindow: locationInWindow)
        }
        divider.onMouseUp = { [weak self] in
            self?.endDrag()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateContent(top: some View, bottom: some View) {
        topHost.rootView = AnyView(
            top.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        )
        bottomHost.rootView = AnyView(
            bottom.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        )
    }

    func setBottomHeight(_ height: CGFloat, commit: Bool) {
        let clamped = clampBottomHeight(height)
        guard abs(clamped - bottomHeight) > 0.01 || commit else {
            if commit { coordinator?.commitHeight(clamped) }
            return
        }
        bottomHeight = clamped
        needsLayout = true
        layoutSubtreeIfNeeded()
        if commit {
            coordinator?.commitHeight(clamped)
        }
    }

    func setBottomVisible(_ visible: Bool) {
        guard isBottomVisible != visible else { return }
        isBottomVisible = visible
        divider.isHidden = !visible
        bottomHost.isHidden = !visible
        needsLayout = true
        layoutSubtreeIfNeeded()
    }

    override func layout() {
        super.layout()
        let bounds = bounds
        let dividerExtent = SplitDividerView.hitExtent

        guard isBottomVisible else {
            topHost.frame = bounds
            divider.frame = .zero
            bottomHost.frame = .zero
            return
        }

        let detailHeight = clampBottomHeight(bottomHeight)
        bottomHeight = detailHeight

        let dividerY = bounds.minY + detailHeight

        bottomHost.frame = CGRect(
            x: bounds.minX,
            y: bounds.minY,
            width: bounds.width,
            height: detailHeight
        )
        divider.frame = CGRect(
            x: bounds.minX,
            y: dividerY,
            width: bounds.width,
            height: dividerExtent
        )
        topHost.frame = CGRect(
            x: bounds.minX,
            y: dividerY + dividerExtent,
            width: bounds.width,
            height: max(0, bounds.height - detailHeight - dividerExtent)
        )
    }

    /// Layout-Max: Platz unter Mindest-Listenhöhe. Content-Max: echte Detail-Inhaltshöhe.
    private func maxBottomHeight() -> CGFloat {
        let layoutMax = max(0, bounds.height - topMinHeight - SplitDividerView.hitExtent)
        guard bottomContentHeight > 0 else { return layoutMax }
        return min(layoutMax, bottomContentHeight)
    }

    private func clampBottomHeight(_ height: CGFloat) -> CGFloat {
        let upper = maxBottomHeight()
        if upper < bottomMinHeight {
            return max(0, upper)
        }
        return min(max(height, bottomMinHeight), upper)
    }

    private func beginDrag(locationInWindow: NSPoint) {
        coordinator?.isDragging = true
        dragStartHeight = clampBottomHeight(bottomHeight)
        dragStartY = locationInWindow.y
    }

    private func continueDrag(locationInWindow: NSPoint) {
        let delta = locationInWindow.y - dragStartY
        setBottomHeight(dragStartHeight + delta, commit: false)
    }

    private func endDrag() {
        let clamped = clampBottomHeight(bottomHeight)
        bottomHeight = clamped
        coordinator?.isDragging = false
        coordinator?.commitHeight(clamped)
        needsLayout = true
        layoutSubtreeIfNeeded()
    }
}

/// Schmale Hit-Area mit sichtbarer 1pt-Linie (HIG: thin divider).
private final class SplitDividerView: NSView {
    static let hitExtent: CGFloat = 8

    var onMouseDown: ((NSPoint) -> Void)?
    var onMouseDragged: ((NSPoint) -> Void)?
    var onMouseUp: (() -> Void)?

    private let lineLayer = CALayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        lineLayer.backgroundColor = NSColor.separatorColor.cgColor
        layer?.addSublayer(lineLayer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        lineLayer.frame = CGRect(x: 0, y: bounds.midY - 0.5, width: bounds.width, height: 1)
        lineLayer.backgroundColor = NSColor.separatorColor.cgColor
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .resizeUpDown)
    }

    override func mouseDown(with event: NSEvent) {
        window?.disableCursorRects()
        NSCursor.resizeUpDown.set()
        onMouseDown?(event.locationInWindow)
    }

    override func mouseDragged(with event: NSEvent) {
        onMouseDragged?(event.locationInWindow)
    }

    override func mouseUp(with event: NSEvent) {
        onMouseUp?()
        window?.enableCursorRects()
        window?.invalidateCursorRects(for: self)
    }
}
