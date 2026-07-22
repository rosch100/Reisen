import AppKit
import SwiftUI

/// Horizontaler Split im Stil von macOS Mail: Spalten stoßen aneinander, kein reservierter
/// Slider-Streifen. Die Hit-Area liegt unsichtbar über der Naht (`resizeLeftRight`).
///
/// Resize läuft in AppKit (Frame-Layout), ohne SwiftUI-Body-Rebuilds während des Ziehens.
/// `leftWidth` wird erst beim Loslassen persistiert.
struct PersistentHorizontalSplitView<Left: View, Right: View>: NSViewRepresentable {
    @Binding var leftWidth: Double
    var leftMinWidth: CGFloat = 200
    var rightMinWidth: CGFloat = 280
    var leftMaxWidth: CGFloat? = nil
    @ViewBuilder var left: () -> Left
    @ViewBuilder var right: () -> Right

    func makeCoordinator() -> HorizontalSplitCoordinator {
        HorizontalSplitCoordinator(leftWidth: $leftWidth)
    }

    func makeNSView(context: Context) -> HorizontalSplitNSView {
        let view = HorizontalSplitNSView(
            leftMinWidth: leftMinWidth,
            rightMinWidth: rightMinWidth,
            leftMaxWidth: leftMaxWidth
        )
        view.coordinator = context.coordinator
        view.setLeftWidth(CGFloat(leftWidth), commit: false)
        view.updateContent(left: left(), right: right())
        return view
    }

    func updateNSView(_ view: HorizontalSplitNSView, context: Context) {
        context.coordinator.leftWidth = $leftWidth
        view.coordinator = context.coordinator
        view.leftMinWidth = leftMinWidth
        view.rightMinWidth = rightMinWidth
        view.leftMaxWidth = leftMaxWidth

        guard !context.coordinator.isDragging else {
            view.needsLayout = true
            return
        }

        view.updateContent(left: left(), right: right())
        view.setLeftWidth(CGFloat(leftWidth), commit: false)
    }
}

final class HorizontalSplitCoordinator {
    var leftWidth: Binding<Double>
    var isDragging = false

    init(leftWidth: Binding<Double>) {
        self.leftWidth = leftWidth
    }

    func commitWidth(_ width: CGFloat) {
        let value = Double(width)
        if abs(leftWidth.wrappedValue - value) > 0.5 {
            leftWidth.wrappedValue = value
        }
    }
}

final class HorizontalSplitNSView: NSView {
    var leftMinWidth: CGFloat
    var rightMinWidth: CGFloat
    var leftMaxWidth: CGFloat?
    weak var coordinator: HorizontalSplitCoordinator?

    private let leftHost = NSHostingView(rootView: AnyView(EmptyView()))
    private let rightHost = NSHostingView(rootView: AnyView(EmptyView()))
    private let divider = HorizontalSplitDividerView()

    private var leftWidth: CGFloat = 240
    private var dragStartWidth: CGFloat = 240
    private var dragStartX: CGFloat = 0

    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: NSView.noIntrinsicMetric)
    }

    init(leftMinWidth: CGFloat, rightMinWidth: CGFloat, leftMaxWidth: CGFloat?) {
        self.leftMinWidth = leftMinWidth
        self.rightMinWidth = rightMinWidth
        self.leftMaxWidth = leftMaxWidth
        super.init(frame: .zero)

        wantsLayer = true
        clipsToBounds = true
        leftHost.sizingOptions = []
        rightHost.sizingOptions = []
        leftHost.clipsToBounds = true
        rightHost.clipsToBounds = true

        for host in [leftHost, rightHost] {
            host.setContentHuggingPriority(.defaultLow, for: .vertical)
            host.setContentHuggingPriority(.defaultLow, for: .horizontal)
            host.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
            host.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        }

        // Divider zuletzt → liegt über der Naht (Hit-Test), ohne Layout-Breite zu verbrauchen.
        addSubview(leftHost)
        addSubview(rightHost)
        addSubview(divider)

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

    func updateContent(left: some View, right: some View) {
        leftHost.rootView = AnyView(
            left.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        )
        rightHost.rootView = AnyView(
            right.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        )
    }

    func setLeftWidth(_ width: CGFloat, commit: Bool) {
        let clamped = clampLeftWidth(width)
        guard abs(clamped - leftWidth) > 0.01 || commit else {
            if commit { coordinator?.commitWidth(clamped) }
            return
        }
        leftWidth = clamped
        needsLayout = true
        layoutSubtreeIfNeeded()
        if commit {
            coordinator?.commitWidth(clamped)
        }
    }

    override func layout() {
        super.layout()
        let bounds = bounds
        let width = clampLeftWidth(leftWidth)
        leftWidth = width

        // Mail: Spalten füllen die gesamte Breite ohne Divider-Gutter.
        leftHost.frame = CGRect(
            x: bounds.minX,
            y: bounds.minY,
            width: width,
            height: bounds.height
        )
        rightHost.frame = CGRect(
            x: bounds.minX + width,
            y: bounds.minY,
            width: max(0, bounds.width - width),
            height: bounds.height
        )

        // Hit-Area zentriert auf der Naht, überlagert beide Spalten (kein Layout-Platz).
        let hit = HorizontalSplitDividerView.hitExtent
        divider.frame = CGRect(
            x: bounds.minX + width - hit / 2,
            y: bounds.minY,
            width: hit,
            height: bounds.height
        )
    }

    private func maxLeftWidth() -> CGFloat {
        let layoutMax = max(0, bounds.width - rightMinWidth)
        if let leftMaxWidth {
            return min(layoutMax, leftMaxWidth)
        }
        return layoutMax
    }

    private func clampLeftWidth(_ width: CGFloat) -> CGFloat {
        let upper = maxLeftWidth()
        if upper < leftMinWidth {
            return max(0, upper)
        }
        return min(max(width, leftMinWidth), upper)
    }

    private func beginDrag(locationInWindow: NSPoint) {
        coordinator?.isDragging = true
        dragStartWidth = clampLeftWidth(leftWidth)
        dragStartX = locationInWindow.x
    }

    private func continueDrag(locationInWindow: NSPoint) {
        let delta = locationInWindow.x - dragStartX
        setLeftWidth(dragStartWidth + delta, commit: false)
    }

    private func endDrag() {
        let clamped = clampLeftWidth(leftWidth)
        leftWidth = clamped
        coordinator?.isDragging = false
        coordinator?.commitWidth(clamped)
        needsLayout = true
        layoutSubtreeIfNeeded()
    }
}

/// Resize-Hit-Area über der Spaltennaht (Mail: kein Gutter). Optional 1pt Separator auf der Naht.
private final class HorizontalSplitDividerView: NSView {
    static let hitExtent: CGFloat = 10

    var onMouseDown: ((NSPoint) -> Void)?
    var onMouseDragged: ((NSPoint) -> Void)?
    var onMouseUp: (() -> Void)?

    private let hairline = CALayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        hairline.backgroundColor = NSColor.separatorColor.cgColor
        layer?.addSublayer(hairline)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        // Nur die Nahtlinie — Hit-Area bleibt unsichtbar drumherum.
        hairline.frame = CGRect(x: bounds.midX - 0.5, y: 0, width: 1, height: bounds.height)
        hairline.backgroundColor = NSColor.separatorColor.cgColor
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .resizeLeftRight)
    }

    override func mouseDown(with event: NSEvent) {
        window?.disableCursorRects()
        NSCursor.resizeLeftRight.set()
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
