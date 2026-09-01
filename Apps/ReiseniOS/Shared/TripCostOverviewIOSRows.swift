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
        TripCostTimelineSummary.make(trip: trip, bookings: bookings, allGaps: allGaps)
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
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .onAppear { refresh() }
        .onChange(of: convertAmountsToPreferredCurrency) { _, _ in refresh() }
        .onChange(of: preferredCurrencyCodeStored) { _, _ in refresh() }
        .onChange(of: summary.costFingerprint) { _, _ in refresh() }
    }

    private func refresh() {
        TripCostOverviewRefresh.run(
            summary: summary,
            convertEnabled: convertAmountsToPreferredCurrency,
            preferredCurrencyStored: preferredCurrencyCodeStored,
            rates: ExchangeRateService.sharedClient,
            setToken: { refreshToken = $0 },
            setResult: { result = $0 },
            currentToken: { refreshToken }
        )
    }
}
