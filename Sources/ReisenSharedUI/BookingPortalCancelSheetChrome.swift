import SwiftUI
import ReisenDomain

public enum BookingPortalCancelChrome {
    public static let systemImage = "arrow.up.right.square"
    public static let usesDestructiveRole = true
}

public struct BookingPortalCancelSheetChrome<WebContent: View>: View {
    let loadFailed: Bool
    let onDismiss: () -> Void
    @ViewBuilder var webContent: () -> WebContent

    public init(
        loadFailed: Bool,
        onDismiss: @escaping () -> Void,
        @ViewBuilder webContent: @escaping () -> WebContent
    ) {
        self.loadFailed = loadFailed
        self.onDismiss = onDismiss
        self.webContent = webContent
    }

    public var body: some View {
        VStack(spacing: 0) {
            if loadFailed {
                Text(L10n.string(.bookingPortalCancelLoadFailed))
                    .font(.callout)
                    .foregroundStyle(.red)
                    .padding(8)
            }
            webContent()
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(L10n.string(.commonCancel), action: onDismiss)
            }
        }
    }
}
