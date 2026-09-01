import SwiftUI
import ReisenData
import ReisenSharedUI

/// SSOT: Titel + Kurzdatum für Sidebar-Buchungszeilen (offen und Trip-Kinder).
struct SidebarBookingOutlineCaption: View {
    let booking: SDBooking

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(booking.presentationTitle)
                .lineLimit(1)
            Text(BookingScheduleRangeText.make(for: booking))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

/// Kompakte Sidebar-Zeile für offene / abgelaufene-offene Buchungen.
struct SidebarOpenBookingOutlineRow: View {
    let booking: SDBooking
    let systemImage: String

    var body: some View {
        Label {
            SidebarBookingOutlineCaption(booking: booking)
        } icon: {
            Image(systemName: systemImage)
        }
        .contentShape(Rectangle())
    }
}
