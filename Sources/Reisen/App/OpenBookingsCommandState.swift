import SwiftUI

struct OpenBookingsCommandState {
    var canCreateTripFromSelection: Bool
}

private struct OpenBookingsCommandStateKey: FocusedValueKey {
    typealias Value = OpenBookingsCommandState
    static let defaultValue: OpenBookingsCommandState? = nil
}

extension FocusedValues {
    var openBookingsCommandState: OpenBookingsCommandState? {
        get { self[OpenBookingsCommandStateKey.self] }
        set { self[OpenBookingsCommandStateKey.self] = newValue }
    }
}
