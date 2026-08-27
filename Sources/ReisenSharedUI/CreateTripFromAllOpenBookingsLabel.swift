import SwiftUI
import ReisenDomain

/// Label for creating a trip from every open unassigned booking (sidebar / title menu).
public struct CreateTripFromAllOpenBookingsLabel: View {
    let count: Int

    public init(count: Int) {
        self.count = count
    }

    public var body: some View {
        Label(
            L10n.format(.actionCreateTripFromAllOpenBookings, count),
            systemImage: "airplane.departure"
        )
    }
}
