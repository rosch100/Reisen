import SwiftUI
import ReisenData
import ReisenDomain

/// Kompakte Zeile für offene Buchungen (Liste macOS/iOS).
public struct OpenBookingRow: View {
    let booking: SDBooking

    public init(booking: SDBooking) {
        self.booking = booking
    }

    public var body: some View {
        let stornoLines = BookingStornoSummary.lines(for: booking)

        VStack(alignment: .leading, spacing: 4) {
            Text(booking.localizedDisplayTitle)
                .lineLimit(1)
                .font(.headline)

            BookingTypeLabel(booking.bookingType)
                .foregroundStyle(.secondary)

            Text(BookingScheduleRangeText.make(for: booking))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if !stornoLines.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(stornoLines) { line in
                        Label {
                            Text(line.text)
                                .font(.caption)
                                .foregroundStyle(line.color)
                                .lineLimit(2)
                        } icon: {
                            Image(systemName: line.systemImage)
                                .font(.caption)
                                .foregroundStyle(line.color)
                        }
                        .labelStyle(.titleAndIcon)
                    }
                }
            }
        }
    }
}
