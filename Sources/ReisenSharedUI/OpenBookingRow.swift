import SwiftUI
import ReisenData
import ReisenDomain

/// Kompakte Zeile für offene Buchungen (Liste macOS/iOS).
public struct OpenBookingRow: View {
    let booking: SDBooking
    let fillCaption: String?

    public init(booking: SDBooking, fillCaption: String? = nil) {
        self.booking = booking
        self.fillCaption = fillCaption
    }

    public var body: some View {
        let stornoLines = BookingStornoSummary.lines(for: booking)

        VStack(alignment: .leading, spacing: 4) {
            Text(booking.presentationTitle)
                .lineLimit(1)
                .font(.headline)

            BookingTypeLabel(booking.bookingType)
                .foregroundStyle(.secondary)

            Text(BookingScheduleRangeText.make(for: booking))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let fillCaption, !fillCaption.isEmpty {
                Text(fillCaption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

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
