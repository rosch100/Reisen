import SwiftUI
import SwiftData
import ReisenDomain
import ReisenData

/// Interleaved bookings + gaps timeline for iOS and SharedUI embedding.
public struct TripTimelineSection<BookingRow: View>: View {
    let trip: SDTrip
    let bookings: [SDBooking]
    let bookingRow: (SDBooking) -> BookingRow

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SDGap.gapStart, order: .forward) private var allGaps: [SDGap]
    @State private var editorPayload: GapEditorPayload?

    public init(
        trip: SDTrip,
        bookings: [SDBooking],
        @ViewBuilder bookingRow: @escaping (SDBooking) -> BookingRow
    ) {
        self.trip = trip
        self.bookings = bookings
        self.bookingRow = bookingRow
    }

    private var savedGapsByKey: [String: SDGap] {
        TripGapTimeline.savedGapsByKey(allGaps: allGaps, tripID: trip.id)
    }

    private var computedGaps: [ComputedGap] {
        TripGapTimeline.computedGaps(trip: trip, bookings: bookings)
    }

    private var timelineItems: [TripTimelineItem] {
        TripTimelineItem.sorted(bookings: bookings, gaps: computedGaps)
    }

    public var body: some View {
        Section(L10n.string(.tripTimeline)) {
            if timelineItems.isEmpty {
                Text(L10n.string(.tripNoBookingsAssigned))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(timelineItems) { item in
                    switch item {
                    case .booking(let booking):
                        bookingRow(booking)
                    case .gap(let gap):
                        gapButton(for: gap)
                    }
                }
            }
        }
        .sheet(item: $editorPayload) { payload in
            GapEditorSheet(payload: payload) { title, kind, price, currency in
                saveGap(payload: payload, title: title, kind: kind, price: price, currency: currency)
            }
        }
    }

    @ViewBuilder
    private func gapButton(for gap: ComputedGap) -> some View {
        let presentation = GapPresentation.resolve(computed: gap, saved: savedGapsByKey[gap.identityKey])

        Button {
            editorPayload = presentation.editorPayload(for: gap)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Label(presentation.displayTitle, systemImage: "arrow.left.arrow.right")
                        .font(.headline)
                    Text("\(gap.gapStart.formatted(date: .abbreviated, time: .shortened)) – \(gap.gapEnd.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(L10n.gapKindDisplay(presentation.effectiveKind))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
    }

    private func saveGap(
        payload: GapEditorPayload,
        title: String,
        kind: GapKind,
        price: Double?,
        currency: String?
    ) {
        do {
            try GapPersistence.upsert(
                payload: payload,
                title: title,
                kind: kind,
                price: price,
                currency: currency,
                trip: trip,
                bookings: bookings,
                existing: savedGapsByKey[payload.key],
                context: modelContext
            )
        } catch {
            assertionFailure("Gap save failed: \(error)")
        }
    }
}
