import SwiftUI
import ReisenDomain
import ReisenData
import ReisenSharedUI

/// Vollständige Buchungsdetails (alle persistierten Felder) — gleiche Ansicht für zugeordnete und offene Buchungen.
struct BookingDetailContent: View {
    let booking: SDBooking
    var isOverlapping: Bool = false
    var overlapCount: Int = 0
    var onEditBooking: (() -> Void)?
    var onRequestManualDeleteBooking: ((UUID) -> Void)?
    var onRequestRemoveFromTrip: ((UUID) -> Void)?

    private var priceText: String {
        let details = booking.rateDetails
        guard let amount = details?.totalPriceAmount else { return BookingDetailLabels.notAvailable }
        return Formatting.formatCurrencyAmount(amount, currencyCode: details?.totalPriceCurrency)
    }

    private var hotelTimeZone: TimeZone { booking.resolvedHotelTimeZone }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(booking.title ?? booking.bookingType.displayLabel)
                        .font(.headline)
                        .textSelection(.enabled)
                    if isOverlapping {
                        Text(L10n.overlapLabel(extraCount: overlapCount))
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 2) {
                    ProviderLogo(providerID: booking.provider)
                    Text(booking.bookingType.displayLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(priceText)
                        .font(.subheadline.weight(.semibold))
                }
            }

            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 160), spacing: 8, alignment: .leading),
            ], alignment: .leading, spacing: 6) {
                ForEach(BookingScheduleFields.make(booking: booking)) { field in
                    detailRow(field.label, field.value)
                }
            }

            if let rate = booking.rateDetails {
                Divider()
                Text(BookingDetailLabels.rateSection)
                    .font(.subheadline.weight(.semibold))
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 160), spacing: 8, alignment: .leading),
                ], alignment: .leading, spacing: 6) {
                    ForEach(BookingRateFields.make(rate: rate, booking: booking)) { field in
                        detailRow(field.label, field.value)
                    }
                }

                if !rate.resolvedRoomItems.isEmpty {
                    Divider()
                    Text(BookingDetailLabels.roomItemsSection)
                        .font(.subheadline.weight(.semibold))
                    BookingRoomItemsView(rate: rate)
                }
            }

            if !booking.resolvedCancellationDeadlines.isEmpty {
                Divider()
                Text(BookingDetailLabels.cancellationSection)
                    .font(.subheadline.weight(.semibold))
                BookingCancellationDeadlinesView(booking: booking, hotelTimeZone: hotelTimeZone)
            }

            if !booking.resolvedGuestHints.isEmpty {
                Divider()
                Text(GuestHintCategory.preTravelImportant.displayTitle)
                    .font(.subheadline.weight(.semibold))
                BookingGuestHintsView(booking: booking)
            }

            if let url = booking.browserURL {
                Divider()
                BookingPortalOpenLink(browserURL: url)
                .font(.caption)
            }

            if let onEditBooking {
                Button(L10n.string(.commonEdit)) {
                    onEditBooking()
                }
                .buttonStyle(.link)
                .padding(.top, 4)
                .help(L10n.string(.tripEditBookingHelp))
            }

            if booking.provider == .manual, let onRequestManualDeleteBooking {
                Button(role: .destructive) {
                    onRequestManualDeleteBooking(booking.id)
                } label: {
                    Text(L10n.string(.actionDeleteEllipsis))
                }
                .buttonStyle(.link)
                .padding(.top, 4)
                .help(L10n.string(.tripDeleteManualHelp))
            }

            if let onRequestRemoveFromTrip {
                Button(role: .destructive) {
                    onRequestRemoveFromTrip(booking.id)
                } label: {
                    Text(L10n.string(.actionRemoveFromTrip))
                }
                .buttonStyle(.link)
                .padding(.top, 4)
                .help(L10n.string(.tripRemoveFromTripHelp))
            }
        }
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption)
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
