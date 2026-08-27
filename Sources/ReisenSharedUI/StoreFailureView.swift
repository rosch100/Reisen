import SwiftUI
import ReisenAppCore
import ReisenDomain

/// Shared store-open failure UI (iOS + macOS) with local reset / optional Cloud wipe.
public struct StoreFailureView: View {
    public let message: String
    public let onReset: (_ wipeCloud: Bool) -> Void
    public var contentPadding: CGFloat
    public var minFrame: CGSize?

    @State private var showResetConfirmation = false
    @State private var showCloudWipeConfirmation = false

    public init(
        message: String,
        contentPadding: CGFloat = 24,
        minFrame: CGSize? = nil,
        onReset: @escaping (_ wipeCloud: Bool) -> Void
    ) {
        self.message = message
        self.contentPadding = contentPadding
        self.minFrame = minFrame
        self.onReset = onReset
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n.string(.storeLoadFailed))
                .font(.title2)
            Text(message)
                .textSelection(.enabled)
                .foregroundStyle(.secondary)

            PublicGitHubIssueReportActions(storeLoadFailureMessage: message)

            Button(L10n.string(.actionResetLocalStores)) {
                showResetConfirmation = true
            }
            .buttonStyle(.borderedProminent)

            Button(L10n.string(.actionClearIcloud), role: .destructive) {
                showCloudWipeConfirmation = true
            }
            .buttonStyle(.bordered)
            .confirmationDialog(
                L10n.string(.actionResetLocalStores),
                isPresented: $showResetConfirmation,
                titleVisibility: .visible
            ) {
                Button(L10n.string(.actionDeleteLocalStores), role: .destructive) {
                    onReset(false)
                }
                Button(L10n.string(.commonCancel), role: .cancel) {}
            } message: {
                Text(L10n.string(.storeResetLocalMessage))
            }
            .confirmationDialog(
                L10n.string(.actionClearIcloud),
                isPresented: $showCloudWipeConfirmation,
                titleVisibility: .visible
            ) {
                Button(L10n.string(.actionClearIcloudAndLocal), role: .destructive) {
                    onReset(true)
                }
                Button(L10n.string(.commonCancel), role: .cancel) {}
            } message: {
                Text(L10n.string(.storeClearIcloudMessage))
            }
        }
        .padding(contentPadding)
        .modifier(OptionalMinFrame(size: minFrame))
    }
}

private struct OptionalMinFrame: ViewModifier {
    let size: CGSize?

    func body(content: Content) -> some View {
        if let size {
            content.frame(minWidth: size.width, minHeight: size.height)
        } else {
            content
        }
    }
}
