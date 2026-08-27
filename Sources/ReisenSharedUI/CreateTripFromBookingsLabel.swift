import SwiftUI
import ReisenDomain

/// SSOT label for „Neue Reise erstellen“ in menus, swipes and context menus.
public struct CreateTripFromBookingsLabel: View {
    public init() {}

    public var body: some View {
        Label(L10n.string(.actionCreateTripFromBookings), systemImage: "airplane.departure")
    }
}
