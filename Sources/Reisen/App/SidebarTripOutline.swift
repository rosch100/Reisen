import SwiftUI
import ReisenData
import ReisenDomain
import ReisenSharedUI

/// Shared Trip-Outline für aktuelle und abgelaufene Reisen (Chevron, Kinder, Context).
struct SidebarTripOutline: View {
    let trip: SDTrip
    let bookings: [SDBooking]
    let gapCount: Int?
    let allowsAddBooking: Bool
    let isTripSelected: Bool
    let selectedTimelineID: String?
    @Binding var isExpanded: Bool

    var onSelectTrip: () -> Void
    var onSelectBooking: (SDBooking) -> Void
    var onEditTrip: () -> Void
    var onDeleteTrip: () -> Void
    var onAddBooking: (SDBooking?) -> Void
    var onEditBooking: (SDBooking) -> Void
    var onRemoveBookingFromTrip: (SDBooking) -> Void
    var onDeleteBooking: (SDBooking) -> Void
    var hasSessionWebView: (SDBooking) -> Bool
    var onPresentCancel: (BookingPortalCancelPresentation, URL, SDBooking) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                if !bookings.isEmpty {
                    Button {
                        isExpanded.toggle()
                    } label: {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 14, height: 14)
                    }
                    .buttonStyle(.plain)
                    .help(isExpanded
                        ? L10n.string(.tripCollapseBookings)
                        : L10n.string(.tripExpandBookings))
                }

                Button(action: onSelectTrip) {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(trip.title)
                            Text(dateRange)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if let meta = L10n.tripCompletenessListMeta(
                                futureBookingCount: bookings.count,
                                gapCount: gapCount
                            ) {
                                Text(meta)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } icon: {
                        Image(systemName: "airplane")
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(UITestingIdentifiers.tripRow(trip.id))
            }
            .tag(SidebarSelection.trip(trip.id))
            .contextMenu {
                Button(L10n.string(.commonEdit), action: onEditTrip)
                if allowsAddBooking {
                    Button(L10n.string(.actionAddBooking)) {
                        onAddBooking(nil)
                    }
                }
                Button(role: .destructive, action: onDeleteTrip) {
                    Text(L10n.string(.actionDeleteTrip))
                }
                .accessibilityIdentifier(UITestingIdentifiers.deleteTripMenu)
            }

            if isExpanded {
                ForEach(bookings) { booking in
                    let isBookingSelected = isTripSelected
                        && selectedTimelineID == booking.id.uuidString
                    Button {
                        onSelectBooking(booking)
                    } label: {
                        SidebarBookingOutlineCaption(booking: booking)
                            .padding(.leading, 28)
                            .padding(.vertical, 4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                isBookingSelected
                                    ? Color.accentColor.opacity(0.15)
                                    : Color.clear
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                    .accessibilityIdentifier(UITestingIdentifiers.bookingRow(booking.id))
                    .contextMenu {
                        Button(L10n.string(.commonEdit)) {
                            onEditBooking(booking)
                        }
                        if allowsAddBooking {
                            Button(L10n.string(.actionAddBooking)) {
                                onAddBooking(booking)
                            }
                        }
                        BookingCopyConfirmationMenuItems(booking: booking)
                        if let url = booking.browserURL {
                            BookingPortalOpenButton(browserURL: url)
                            CopyLinkMenuItem(url: url)
                        }
                        BookingPortalCancelMenuItems(
                            booking: booking,
                            hasSessionWebView: hasSessionWebView(booking),
                            onPresentCancel: { presentation, url in
                                onPresentCancel(presentation, url, booking)
                            }
                        )
                        Button(role: .destructive) {
                            onRemoveBookingFromTrip(booking)
                        } label: {
                            Text(L10n.string(.actionRemoveFromTrip))
                        }
                        Button(role: .destructive) {
                            onDeleteBooking(booking)
                        } label: {
                            Text(L10n.string(.actionDeleteEllipsis))
                        }
                    }
                }
            }
        }
    }

    private var dateRange: String {
        let start = trip.startDate.formatted(date: .abbreviated, time: .omitted)
        let end = trip.endDate.formatted(date: .abbreviated, time: .omitted)
        return "\(start) – \(end)"
    }
}
