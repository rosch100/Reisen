import SwiftUI
import ReisenDomain

/// Adaptive Anordnung: Status/Guidance und Credential-CTAs nebeneinander bei genug Breite.
///
/// Misst die verfügbare Breite und nutzt `SyncBrowserChrome.loginChromeArrangement` —
/// kein `ViewThatFits`+`minWidth`-Hack (Regression #145: WebView-Churn / leere Login-Fläche).
public struct SyncLoginChromeAdaptiveLayout<Status: View, Credentials: View>: View {
    private let status: Status
    private let credentials: Credentials

    @State private var availableWidth: CGFloat = 0

    public init(
        @ViewBuilder status: () -> Status,
        @ViewBuilder credentials: () -> Credentials
    ) {
        self.status = status()
        self.credentials = credentials()
    }

    public var body: some View {
        Group {
            switch SyncBrowserChrome.loginChromeArrangement(
                availableWidth: Double(availableWidth)
            ) {
            case .sideBySide:
                HStack(alignment: .top, spacing: 16) {
                    status
                        .frame(maxWidth: .infinity, alignment: .leading)
                    credentials
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            case .stacked:
                VStack(alignment: .leading, spacing: 12) {
                    status
                    credentials
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .background(
            GeometryReader { proxy in
                Color.clear
                    .preference(
                        key: SyncLoginChromeWidthKey.self,
                        value: proxy.size.width
                    )
            }
        )
        .onPreferenceChange(SyncLoginChromeWidthKey.self) { width in
            guard width > 0, width != availableWidth else { return }
            availableWidth = width
        }
    }
}

private enum SyncLoginChromeWidthKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
