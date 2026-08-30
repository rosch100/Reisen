import SwiftUI

private enum AdaptiveUsesSplitNavigationKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// `true` when embedded in `NavigationSplitView` (regular width).
    var adaptiveUsesSplitNavigation: Bool {
        get { self[AdaptiveUsesSplitNavigationKey.self] }
        set { self[AdaptiveUsesSplitNavigationKey.self] = newValue }
    }
}

/// Regular width: `NavigationSplitView`. Compact: `NavigationStack`.
struct AdaptiveListDetail<ListContent: View, DetailContent: View, EmptyDetail: View, Selection: Hashable>: View {
    @Binding var selection: Selection?
    /// Einmaliger Compact-Push (z. B. nach Paste-Import-Sichern), ohne List-Selection-Doppelpush.
    @Binding var compactPush: Selection?
    @ViewBuilder var list: () -> ListContent
    @ViewBuilder var detail: (Selection) -> DetailContent
    @ViewBuilder var emptyDetail: () -> EmptyDetail

    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var compactPath = NavigationPath()

    private var usesSplit: Bool { sizeClass == .regular }

    init(
        selection: Binding<Selection?>,
        compactPush: Binding<Selection?> = .constant(nil),
        @ViewBuilder list: @escaping () -> ListContent,
        @ViewBuilder detail: @escaping (Selection) -> DetailContent,
        @ViewBuilder emptyDetail: @escaping () -> EmptyDetail
    ) {
        self._selection = selection
        self._compactPush = compactPush
        self.list = list
        self.detail = detail
        self.emptyDetail = emptyDetail
    }

    var body: some View {
        if usesSplit {
            NavigationSplitView {
                list()
                    .environment(\.adaptiveUsesSplitNavigation, true)
            } detail: {
                if let selection {
                    detail(selection)
                } else {
                    emptyDetail()
                }
            }
        } else {
            NavigationStack(path: $compactPath) {
                list()
                    .environment(\.adaptiveUsesSplitNavigation, false)
            }
            .onChange(of: compactPush) { _, newValue in
                guard let newValue else { return }
                compactPath.append(newValue)
                compactPush = nil
            }
        }
    }
}

/// `navigationDestination(for: UUID)` only in compact stack navigation (avoids iPad double-push).
struct CompactUUIDDestination<Destination: View>: ViewModifier {
    let enabled: Bool
    @ViewBuilder var destination: (UUID) -> Destination

    func body(content: Content) -> some View {
        if enabled {
            content.navigationDestination(for: UUID.self, destination: destination)
        } else {
            content
        }
    }
}

/// Split: Button setzt Selection. Compact: NavigationLink.
struct AdaptiveUUIDSelectionRow<Label: View>: View {
    let id: UUID
    @Binding var selection: UUID?
    let usesSplit: Bool
    @ViewBuilder var label: () -> Label

    var body: some View {
        if usesSplit {
            Button {
                selection = id
            } label: {
                label()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        } else {
            NavigationLink(value: id) {
                label()
            }
        }
    }
}
