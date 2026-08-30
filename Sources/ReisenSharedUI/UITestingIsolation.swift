import SwiftUI
import ReisenAppCore

public struct UITestingIsolationModifier: ViewModifier {
    public init() {}

    public func body(content: Content) -> some View {
        if UITestingLaunch.isActive {
            content.defaultAppStorage(UITestingLaunch.isolatedDefaults)
        } else {
            content
        }
    }
}

public extension View {
    func uiTestingIsolation() -> some View {
        modifier(UITestingIsolationModifier())
    }
}
