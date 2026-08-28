import SwiftUI
import ReisenDomain

/// Layout-Stil für Label+Wert (iOS-Liste vs. macOS-Inspector-Grid).
public enum CopyableLabeledValueStyle: Sendable, Equatable {
    /// `LabeledContent` — eine List-Zeile auf iOS.
    case list
    /// Caption-Label über dem Wert — macOS-Detailgrid.
    case inspector

    /// Typische Wert-Schrift in Detail-Blöcken (Room/Storno/Hints).
    var detailValueTextStyle: CopyableValueTextStyle {
        switch self {
        case .list: .body
        case .inspector: .caption2
        }
    }

    /// Titel-Zeile in Hint-/Room-Blöcken (Inspector etwas größer als Detail).
    var titleValueTextStyle: CopyableValueTextStyle {
        switch self {
        case .list: .body
        case .inspector: .caption
        }
    }
}

/// Label + kopierbarer Wert (SSOT für Info-Felder).
public struct CopyableLabeledValue: View {
    let label: String
    let value: String
    let kind: FieldCopyKind
    let style: CopyableLabeledValueStyle
    var valueTextStyle: CopyableValueTextStyle
    var valueLineLimit: Int?

    public init(
        label: String,
        value: String,
        kind: FieldCopyKind = .standard,
        style: CopyableLabeledValueStyle,
        valueTextStyle: CopyableValueTextStyle? = nil,
        valueLineLimit: Int? = nil
    ) {
        self.label = label
        self.value = value
        self.kind = kind
        self.style = style
        self.valueTextStyle = valueTextStyle ?? style.titleValueTextStyle
        self.valueLineLimit = valueLineLimit ?? (style == .inspector ? 3 : nil)
    }

    public init(
        field: BookingRateField,
        style: CopyableLabeledValueStyle,
        valueTextStyle: CopyableValueTextStyle? = nil,
        valueLineLimit: Int? = nil
    ) {
        self.init(
            label: field.label,
            value: field.value,
            kind: field.copyKind,
            style: style,
            valueTextStyle: valueTextStyle,
            valueLineLimit: valueLineLimit
        )
    }

    public var body: some View {
        switch style {
        case .list:
            LabeledContent {
                valueView
            } label: {
                Text(label)
            }
        case .inspector:
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                valueView
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var valueView: some View {
        CopyableFieldValue(
            value: value,
            kind: kind,
            textStyle: valueTextStyle,
            lineLimit: valueLineLimit
        )
    }
}
