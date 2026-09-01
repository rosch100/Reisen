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
    var onRequestDeleteBooking: ((UUID) -> Void)?
    var onRequestRemoveFromTrip: ((UUID) -> Void)?
    var hasSessionWebView: Bool
    var onPresentCancel: (BookingPortalCancelPresentation, URL) -> Void

    private var priceText: String {
        let details = booking.rateDetails
        guard let amount = details?.totalPriceAmount else { return BookingDetailLabels.notAvailable }
        return Formatting.formatCurrencyAmount(amount, currencyCode: details?.totalPriceCurrency)
    }

    private var titleText: String {
        booking.presentationTitle
    }

    private var hotelTimeZone: TimeZone { booking.resolvedHotelTimeZone }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    CopyableFieldValue(
                        value: titleText,
                        kind: .standard,
                        textStyle: .headline,
                        lineLimit: 3
                    )
                    if isOverlapping {
                        Text(L10n.overlapLabel(extraCount: overlapCount))
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                    BookingElapsedLabel(for: booking)
                }
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 2) {
                    ProviderLogo(providerID: booking.provider)
                    Text(booking.bookingType.displayLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    CopyableFieldValue(
                        value: priceText,
                        kind: .standard,
                        textStyle: .subheadline,
                        lineLimit: 1
                    )
                }
            }

            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 160), spacing: 8, alignment: .leading),
            ], alignment: .leading, spacing: 6) {
                ForEach(BookingScheduleFields.make(booking: booking)) { field in
                    CopyableLabeledValue(field: field, style: .inspector)
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
                        CopyableLabeledValue(field: field, style: .inspector)
                    }
                }

                if !rate.resolvedRoomItems.isEmpty {
                    Divider()
                    Text(BookingDetailLabels.roomItemsSection)
                        .font(.subheadline.weight(.semibold))
                    BookingRoomItemsView(rate: rate, style: .inspector)
                }
            }

            if !booking.resolvedCancellationDeadlines.isEmpty {
                Divider()
                Text(BookingDetailLabels.cancellationSection)
                    .font(.subheadline.weight(.semibold))
                BookingCancellationDeadlinesView(
                    booking: booking,
                    hotelTimeZone: hotelTimeZone,
                    style: .inspector
                )
            }

            if !booking.resolvedGuestHints.isEmpty {
                Divider()
                Text(GuestHintCategory.preTravelImportant.displayTitle)
                    .font(.subheadline.weight(.semibold))
                BookingGuestHintsView(booking: booking, style: .inspector)
            }

            Divider()
            if BookingPortalActionBar.isVisible(
                booking: booking,
                hasSessionWebView: hasSessionWebView
            ) {
                BookingPortalActionBar(
                    booking: booking,
                    openTitle: BookingPortalOpenTitle.short,
                    openHelp: BookingPortalOpenTitle.openInBrowserHelp,
                    openButtonStyle: .bordered,
                    showsCopyMenu: true,
                    hasSessionWebView: hasSessionWebView,
                    onPresentCancel: onPresentCancel
                )
                .font(.caption)
            } else {
                Text(L10n.string(.bookingDetailNoBrowserLink))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let onEditBooking {
                Button(L10n.string(.commonEdit)) {
                    onEditBooking()
                }
                .buttonStyle(.link)
                .padding(.top, 4)
                .help(L10n.string(.tripEditBookingHelp))
            }

            if let onRequestDeleteBooking {
                Button(role: .destructive) {
                    onRequestDeleteBooking(booking.id)
                } label: {
                    Text(L10n.string(.actionDeleteEllipsis))
                }
                .buttonStyle(.link)
                .padding(.top, 4)
                .help(L10n.string(.bookingDeleteHelp))
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
}
