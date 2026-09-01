import SwiftUI
import ReisenData
import ReisenSharedUI

/// Kompakte Sidebar-Zeile für offene / abgelaufene-offene Buchungen (Titel + Kurzdatum).
struct SidebarOpenBookingOutlineRow: View {
    let booking: SDBooking
    let systemImage: String

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(booking.presentationTitle)
                    .lineLimit(1)
                Text(BookingScheduleRangeText.make(for: booking))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: systemImage)
        }
        .contentShape(Rectangle())
    }
}
