import SwiftUI
import ReisenDomain

/// Adaptive Anordnung: Status/Guidance und Credential-CTAs nebeneinander bei genug Breite.
public struct SyncLoginChromeAdaptiveLayout<Status: View, Credentials: View>: View {
    private let status: Status
    private let credentials: Credentials

    public init(
        @ViewBuilder status: () -> Status,
        @ViewBuilder credentials: () -> Credentials
    ) {
        self.status = status()
        self.credentials = credentials()
    }

    public var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 16) {
                status
                    .frame(maxWidth: .infinity, alignment: .leading)
                credentials
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minWidth: SyncBrowserChrome.sideBySideMinimumWidth, alignment: .leading)

            VStack(alignment: .leading, spacing: 12) {
                status
                credentials
            }
        }
    }
}
