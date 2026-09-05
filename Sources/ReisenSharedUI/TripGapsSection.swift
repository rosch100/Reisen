import SwiftUI
import SwiftData
import ReisenDomain
import ReisenData
import ReisenDiagnostics

/// Interleaved bookings + gaps timeline for iOS and SharedUI embedding.
public struct TripTimelineSection<BookingRow: View>: View {
    let trip: SDTrip
    let bookings: [SDBooking]
    let bookingRow: (SDBooking) -> BookingRow

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SDGap.gapStart, order: .forward) private var allGaps: [SDGap]
    @State private var editorPayload: GapEditorPayload?
    @State private var persistErrorMessage: String?

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
                    case .createDraft:
                        EmptyView()
                    }
                }
            }
        }
        .sheet(item: $editorPayload) { payload in
            GapEditorSheet(payload: payload) { title, kind, price, currency in
                saveGap(payload: payload, title: title, kind: kind, price: price, currency: currency)
            }
        }
        .persistFailureAlert(message: $persistErrorMessage)
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
                    Text(gapRangeText(for: gap))
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
        .contextMenu {
            let rangeText = gapRangeText(for: gap)
            GapCopyMenuItems(
                title: presentation.displayTitle,
                rangeText: rangeText,
                kindLabel: L10n.gapKindDisplay(presentation.effectiveKind),
                priceText: presentation.priceText
            )
        }
    }

    private func gapRangeText(for gap: ComputedGap) -> String {
        let tz = HotelTimeZone.resolve(
            fromOffsetSeconds: gap.fromBooking.hotelOffsetSeconds,
            toOffsetSeconds: gap.toBooking.hotelOffsetSeconds
        )
        let start = Formatting.formatOrtszeit(gap.gapStart, dateFormat: "d.M. HH:mm", timeZone: tz)
        let end = Formatting.formatOrtszeit(gap.gapEnd, dateFormat: "d.M. HH:mm", timeZone: tz)
        return "\(start) – \(end)"
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
            recordGapSave(result: .succeeded, reason: "upsert")
        } catch {
            persistErrorMessage = String(describing: error)
            recordGapSave(result: .failed, reason: String(describing: type(of: error)))
        }
    }

    private func recordGapSave(result: DiagnosticResult, reason: String) {
        Task {
            await DiagnosticLogger.shared.record(
                DiagnosticEvent(
                    context: DiagnosticContext(
                        runID: UUID(),
                        providerID: .manual,
                        operation: "trip_gap_save"
                    ),
                    component: "TripTimelineSection",
                    phase: "persist",
                    event: "gap_save",
                    result: result,
                    reason: reason,
                    visibility: .publicDiagnostic
                )
            )
        }
    }
}
