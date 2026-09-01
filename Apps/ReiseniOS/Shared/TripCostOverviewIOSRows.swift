import SwiftUI
import SwiftData
import ReisenDomain
import ReisenData
import ReisenSharedUI
import ReisenAppCore

/// iOS Trip-Übersicht: Kostensumme mit optionaler Umrechnung.
struct TripCostOverviewIOSRows: View {
    let trip: SDTrip

    @Query(sort: \SDGap.gapStart, order: .forward) private var allGaps: [SDGap]
    @AppStorage(AppSettingsKeys.convertAmountsToPreferredCurrency) private var convertAmountsToPreferredCurrency = false
    @AppStorage(AppSettingsKeys.preferredCurrencyCode) private var preferredCurrencyCodeStored = ""
    @State private var result: TripCostOverviewResult = .empty
    @State private var refreshToken = UUID()

    private var bookings: [SDBooking] { trip.timelineBookings() }

    private var summary: TripCostSummary {
        let saved = TripGapTimeline.savedGapsByKey(allGaps: allGaps, tripID: trip.id)
        let computed = TripGapTimeline.computedGaps(trip: trip, bookings: bookings)
        let gapPairs: [(Double?, String?)] = computed.map { gap in
            let model = saved[gap.identityKey]
            return (model?.priceAmount, model?.priceCurrencyCode)
        }
        return TripCostLineMapping.summary(bookings: bookings, gapPairs: gapPairs)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            CopyableLabeledValue(
                label: L10n.string(.bookingDetailPrice),
                value: TripCostDisplayText.primaryLine(for: result),
                kind: .standard,
                style: .list
            )
            if let secondary = TripCostDisplayText.secondaryLine(for: result) {
                Text(secondary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear { refresh() }
        .onChange(of: convertAmountsToPreferredCurrency) { _, _ in refresh() }
        .onChange(of: preferredCurrencyCodeStored) { _, _ in refresh() }
        .onChange(of: bookings.map(\.id)) { _, _ in refresh() }
    }

    private func refresh() {
        let costSummary = summary
        let convert = convertAmountsToPreferredCurrency
        let preferred = preferredCurrencyCodeStored.isEmpty
            ? AppSettingsKeys.preferredCurrency()
            : preferredCurrencyCodeStored
        let token = UUID()
        refreshToken = token
        Task { @MainActor in
            let loaded = await TripCostOverviewLoader.load(
                summary: costSummary,
                convertEnabled: convert,
                preferredCurrency: preferred,
                rates: ExchangeRateService.sharedClient
            )
            guard refreshToken == token else { return }
            result = loaded
        }
    }
}