import SwiftUI
import ReisenDomain
#if os(macOS)
import AppKit
#endif

/// Textstil für `CopyableFieldValue` (explizit, ohne Font-Gleichheit).
public enum CopyableValueTextStyle: Sendable, Equatable {
    case body
    case subheadline
    case caption
    case caption2
    case headline

    var swiftUIFont: Font {
        switch self {
        case .body: .body
        case .subheadline: .subheadline
        case .caption: .caption
        case .caption2: .caption2
        case .headline: .headline
        }
    }

    #if os(macOS)
    var nsFont: NSFont {
        switch self {
        case .body:
            return NSFont.preferredFont(forTextStyle: .body)
        case .subheadline:
            return NSFont.preferredFont(forTextStyle: .subheadline)
        case .caption:
            return NSFont.preferredFont(forTextStyle: .caption1)
        case .caption2:
            // AppKit hat kein `.caption2`; etwas kleiner als Caption1 (iOS-Parität Title vs. Detail).
            let caption = NSFont.preferredFont(forTextStyle: .caption1)
            return NSFont.systemFont(ofSize: max(9, floor(caption.pointSize - 1)), weight: .regular)
        case .headline:
            return NSFont.preferredFont(forTextStyle: .headline)
        }
    }

    var nsMonospacedFont: NSFont {
        .monospacedSystemFont(ofSize: nsFont.pointSize, weight: .regular)
    }
    #endif
}

/// Darstellung eines kopierbaren Feldwerts (ohne Label).
public struct CopyableFieldValue: View {
    private static let copiedFeedbackDuration: Duration = .milliseconds(1_200)

    let value: String
    let kind: FieldCopyKind
    var textStyle: CopyableValueTextStyle
    /// Plattformübergreifend als `Color` (macOS → `NSColor` für `CopyableTextView`).
    var foregroundColor: Color
    var lineLimit: Int?

    @Environment(\.stringPasteboard) private var pasteboard
    @State private var copyPulse = 0
    @State private var showCopiedCheck = false

    public init(
        value: String,
        kind: FieldCopyKind = .standard,
        textStyle: CopyableValueTextStyle = .body,
        foregroundStyle: Color = .primary,
        lineLimit: Int? = nil
    ) {
        self.value = value
        self.kind = kind
        self.textStyle = textStyle
        self.foregroundColor = foregroundStyle
        self.lineLimit = lineLimit
    }

    public var body: some View {
        Group {
            switch kind {
            case .standard:
                standardBody
            case .identifier:
                identifierBody
                    .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.6), trigger: copyPulse)
                    .onChange(of: value) { _, _ in showCopiedCheck = false }
                    .task(id: copyPulse) {
                        guard copyPulse > 0, showCopiedCheck else { return }
                        try? await Task.sleep(for: Self.copiedFeedbackDuration)
                        guard !Task.isCancelled else { return }
                        showCopiedCheck = false
                    }
            }
        }
        .contextMenu { copyMenuButton }
        .accessibilityAction(named: Text(L10n.string(.commonCopy))) {
            performCopy()
        }
    }

    @ViewBuilder
    private var standardBody: some View {
        #if os(macOS)
        macOSText(font: textStyle.nsFont, maximumNumberOfLines: lineLimit ?? 0)
        #else
        Text(value)
            .font(textStyle.swiftUIFont)
            .foregroundStyle(foregroundColor)
            .lineLimit(lineLimit)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
        #endif
    }

    @ViewBuilder
    private var identifierBody: some View {
        #if os(macOS)
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            macOSText(font: textStyle.nsMonospacedFont, maximumNumberOfLines: lineLimit ?? 1)
                // Doppelklick: Copy ohne First-Responder/Selektion zu stehlen (Einfachklick → Cmd+C).
                .onTapGesture(count: 2) { performCopy() }

            copiedCheckmark
        }
        .help(L10n.string(.commonCopy))
        #else
        Button(action: performCopy) {
            HStack(spacing: 6) {
                Text(value)
                    .font(textStyle.swiftUIFont)
                    .fontDesign(.monospaced)
                    .foregroundStyle(foregroundColor)
                    .lineLimit(lineLimit)
                copiedCheckmark
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        #endif
    }

    #if os(macOS)
    private func macOSText(font: NSFont, maximumNumberOfLines: Int) -> some View {
        CopyableTextView(
            text: value,
            font: font,
            textColor: NSColor(foregroundColor),
            maximumNumberOfLines: maximumNumberOfLines,
            lineBreakMode: .byTruncatingTail
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    #endif

    @ViewBuilder
    private var copiedCheckmark: some View {
        if showCopiedCheck {
            Image(systemName: "checkmark")
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private var copyMenuButton: some View {
        Button(L10n.string(.commonCopy)) {
            performCopy()
        }
        .disabled(value.isEmpty)
    }

    private func performCopy() {
        guard !value.isEmpty else { return }
        CopyAccessibility.copy(value, using: pasteboard)
        guard kind == .identifier else { return }
        copyPulse += 1
        showCopiedCheck = true
    }
}
