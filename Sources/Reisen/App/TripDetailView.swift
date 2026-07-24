import SwiftUI
import SwiftData
import ReisenDomain
import ReisenData
import ReisenProviders
import ReisenSharedUI
import AppKit
import Foundation

func formatCurrencyAmount(_ amount: Double, currencyCode: String?) -> String {
    let currency = currencyCode ?? "EUR"
    let formatter = NumberFormatter()
    formatter.locale = Locale(identifier: "de_DE_POSIX")
    formatter.numberStyle = .currency
    formatter.currencyCode = currency
    formatter.maximumFractionDigits = 2
    return formatter.string(from: NSNumber(value: amount)) ?? "\(amount) \(currency)"
}

func isOpenBookingCandidate(
    _ booking: SDBooking,
    for trip: SDTrip,
    calendar: Calendar = .current,
    now: Date = Date()
) -> Bool {
    guard booking.trip == nil, booking.status != .cancelled else { return false }
    let startOfToday = calendar.startOfDay(for: now)
    let tripStartDay = calendar.startOfDay(for: trip.startDate)
    let tripEndDay = calendar.startOfDay(for: trip.endDate)
    let bookingStartDay = calendar.startOfDay(for: booking.startAt)
    let bookingEndDay = calendar.startOfDay(for: booking.endAt)
    return bookingStartDay >= startOfToday
        && bookingStartDay >= tripStartDay
        && bookingEndDay <= tripEndDay
}

private func formatOrtszeit(_ date: Date, dateFormat: String, timeZone: TimeZone) -> String {
    let df = DateFormatter()
    df.locale = Locale(identifier: "de_DE_POSIX")
    df.timeZone = timeZone
    df.dateFormat = dateFormat
    return df.string(from: date)
}

private func minutesToHHmm(_ minutes: Int) -> String {
    String(format: "%02d:%02d", minutes / 60, minutes % 60)
}

struct TripDetailView: View {
    enum Mode {
        case list
        case detail
    }

    let mode: Mode
    @Bindable var trip: SDTrip
    @Binding var selectedTimelineID: String?
    @Binding var gapOverrides: [String: GapOverride]
    @Binding var gapEditorPayload: GapEditorPayload?
    @Binding var bookingEditorSession: BookingEditorSession?

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SDBooking.startAt, order: .forward) private var allBookings: [SDBooking]
    @Query(sort: \SDGap.gapStart, order: .forward) private var allGaps: [SDGap]

    struct GapOverride {
        var title: String
        var kind: GapKind
    }

    struct GapEditorPayload: Identifiable, Equatable {
        let id: String
        let title: String
        let kind: GapKind
        let priceAmount: Double?
        let priceCurrencyCode: String?
        let gapStart: Date
        let gapEnd: Date
        let fromBookingID: UUID
        let toBookingID: UUID
    }

    private var sortedBookings: [SDBooking] {
        let startOfToday = Calendar.current.startOfDay(for: Date())
        return trip.bookings
            .filter { $0.startAt >= startOfToday && $0.status != .cancelled }
            .sorted { $0.startAt < $1.startAt }
    }

    private var tripTotalPriceText: String {
        let bookingAmounts = sortedBookings.compactMap { $0.rateDetails?.totalPriceAmount }

        let gapAmounts = gaps.compactMap { gap in
            let key = gapKey(for: gap)
            return savedGapsByKey[key]?.priceAmount
        }

        let amounts = bookingAmounts + gapAmounts
        guard !amounts.isEmpty else { return "k.A." }

        let bookingCurrency = sortedBookings.compactMap { $0.rateDetails?.totalPriceCurrency }.first
        let gapCurrency = gaps.compactMap { gap in
            let key = gapKey(for: gap)
            return savedGapsByKey[key]?.priceCurrencyCode
        }.first

        let currency = bookingCurrency ?? gapCurrency
        let total = amounts.reduce(0, +)
        return formatCurrencyAmount(total, currencyCode: currency)
    }

    private var savedGapsByKey: [String: SDGap] {
        let tripGaps = allGaps.filter { $0.trip?.id == trip.id }
        var result: [String: SDGap] = [:]
        for g in tripGaps {
            if let key = g.identityKey, !key.isEmpty {
                result[key] = g
            }
        }
        return result
    }

    private var overlapCountsByBookingID: [UUID: Int] {
        var counts: [UUID: Int] = [:]
        let calendar = Calendar.current

        func day(_ d: Date) -> Date { calendar.startOfDay(for: d) }

        func samePlaceAndDates(_ a: SDBooking, _ b: SDBooking) -> Bool {
            // Mehrfachbuchungen (z.B. mehrere Zimmer) sollen nicht als „Überschneidung“ markiert werden.
            let aLoc = a.locationTo ?? a.locationFrom ?? ""
            let bLoc = b.locationTo ?? b.locationFrom ?? ""
            guard !aLoc.isEmpty, !bLoc.isEmpty, aLoc == bLoc else { return false }
            return day(a.startAt) == day(b.startAt) && day(a.endAt) == day(b.endAt)
        }

        for a in sortedBookings {
            var overlapCount = 0
            for b in sortedBookings where b.id != a.id {
                guard !samePlaceAndDates(a, b) else { continue }

                // Keine Überschneidung, wenn Abreise-Datum == Anreise-Datum (Kalendertag-beruhigt).
                // Wir betrachten das Ende als „exclusive“ (Anreise am gleichen Tag teilt keinen Tag).
                let aStart = day(a.startAt)
                let aEnd = day(a.endAt)
                let bStart = day(b.startAt)
                let bEnd = day(b.endAt)

                let overlaps = max(aStart, bStart) < min(aEnd, bEnd)
                if overlaps { overlapCount += 1 }
            }
            if overlapCount > 0 { counts[a.id] = overlapCount }
        }
        return counts
    }

    private var gaps: [ComputedGap] {
        GapDetector().computeGaps(
            bookings: sortedBookings.map(DomainMapper.booking(from:)),
            tripStart: trip.startDate,
            tripEnd: trip.endDate
        )
    }

    private func selectTimelineID(_ id: String) {
        selectedTimelineID = id
    }

    private func editBooking(_ booking: SDBooking) {
        selectTimelineID(booking.id.uuidString)
        bookingEditorSession = .edit(bookingID: booking.id)
    }

    private func startCreateBooking(prefillStart: Date?, prefillEnd: Date?, selectID: String?) {
        if let selectID { selectTimelineID(selectID) }
        bookingEditorSession = .create(prefillStart: prefillStart, prefillEnd: prefillEnd)
    }

    private func removeBookingFromTrip(_ booking: SDBooking, fallbackTimelineID: String?) {
        booking.trip = nil
        try? modelContext.save()

        let removedID = booking.id.uuidString
        if selectedTimelineID == removedID {
            selectedTimelineID = (removedID == fallbackTimelineID) ? nil : fallbackTimelineID
        }

        if case .edit(let editingID) = bookingEditorSession,
           editingID == booking.id {
            bookingEditorSession = nil
        }
    }

    private func requestDeleteManualBooking(_ booking: SDBooking) {
        selectTimelineID(booking.id.uuidString)
        pendingManualDeleteBookingID = booking.id
        showManualDeleteConfirmation = true
    }

    private func requestRemoveBookingFromTrip(_ booking: SDBooking) {
        selectTimelineID(booking.id.uuidString)
        pendingRemoveFromTripBookingID = booking.id
        showRemoveFromTripConfirmation = true
    }

    @State private var showAssignBookings = false
    @State private var pendingManualDeleteBookingID: UUID?
    @State private var showManualDeleteConfirmation = false
    @State private var pendingRemoveFromTripBookingID: UUID?
    @State private var showRemoveFromTripConfirmation = false

    var body: some View {
        let timelineItems = timelineItems(gaps: gaps, bookings: sortedBookings)
        let selectedTimelineItem: TimelineItem? = {
            guard let selectedTimelineID else { return nil }
            return timelineItems.first { $0.id == selectedTimelineID }
        }()

        // Für Mail-ähnliches UX: bei leerer Selektion automatisch erste passende Buchung auswählen.
        let firstBookingTimelineID: String? = timelineItems.first {
            if case .booking = $0 { return true }
            return false
        }?.id

        if mode == .list {
            VStack(alignment: .leading, spacing: 0) {
                tripOverviewSection
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .fixedSize(horizontal: false, vertical: true)

                Divider()

                Text("Buchungen")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
                    .padding(.bottom, 4)
                    .fixedSize(horizontal: false, vertical: true)

                if timelineItems.isEmpty {
                    ContentUnavailableView {
                        Label("Keine Buchungen", systemImage: "calendar.badge.exclamationmark")
                    } description: {
                        Text("Dieser Reise sind noch keine zukünftigen Buchungen zugeordnet.")
                    } actions: {
                        Button("Buchung hinzufügen…") {
                            startCreateBooking(prefillStart: nil, prefillEnd: nil, selectID: nil)
                        }
                        Button("Buchungen zuordnen…") {
                            showAssignBookings = true
                        }
                        .disabled(openBookingsCandidates().isEmpty)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    bookingsList(timelineItems: timelineItems, fallbackTimelineID: firstBookingTimelineID)
                }
            }
            .navigationTitle(trip.title)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Buchungen zuordnen…") {
                        showAssignBookings = true
                    }
                    .disabled(openBookingsCandidates().isEmpty)
                    .help(openBookingsCandidates().isEmpty
                        ? "Keine offenen Buchungen im Reisezeitraum"
                        : "Offene Buchungen dieser Reise zuordnen")
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Buchung hinzufügen…") {
                        startCreateBooking(prefillStart: nil, prefillEnd: nil, selectID: nil)
                    }
                    .help("Manuelle Buchung für diese Reise anlegen")
                }
            }
            .sheet(isPresented: $showAssignBookings) {
                AssignBookingsSheet(
                    trip: trip,
                    candidates: openBookingsCandidates()
                )
            }
            .onAppear {
                guard selectedTimelineID == nil else { return }
                selectedTimelineID = firstBookingTimelineID
            }
            .onChange(of: trip.id) { _, _ in
                bookingEditorSession = nil
                guard selectedTimelineID == nil else { return }
                selectedTimelineID = firstBookingTimelineID
            }
            .onReceive(NotificationCenter.default.publisher(for: .reisenAssignBookings)) { _ in
                guard !openBookingsCandidates().isEmpty else { return }
                showAssignBookings = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .reisenAddBooking)) { _ in
                startCreateBooking(
                    prefillStart: nil,
                    prefillEnd: nil,
                    selectID: selectedTimelineID
                )
            }
            .onReceive(NotificationCenter.default.publisher(for: .reisenRequestRemoveBookingFromTrip)) { note in
                guard let bookingID = note.object as? UUID,
                      let booking = trip.bookings.first(where: { $0.id == bookingID }) else { return }
                requestRemoveBookingFromTrip(booking)
            }
            .onReceive(NotificationCenter.default.publisher(for: .reisenRequestDeleteManualBooking)) { note in
                guard let bookingID = note.object as? UUID,
                      let booking = trip.bookings.first(where: { $0.id == bookingID }),
                      booking.provider == .manual else { return }
                requestDeleteManualBooking(booking)
            }
            .confirmationDialog(
                "Buchung wirklich löschen?",
                isPresented: $showManualDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Löschen", role: .destructive) {
                    guard let bookingIDToDelete = pendingManualDeleteBookingID else { return }

                    if let bookingToDelete = trip.bookings.first(where: { $0.id == bookingIDToDelete }) {
                        modelContext.delete(bookingToDelete)
                        try? modelContext.save()
                    }

                    // Auswahl zurück auf die erste verbleibende Buchung setzen.
                    let startOfToday = Calendar.current.startOfDay(for: Date())
                    let remaining = trip.bookings
                        .filter { $0.startAt >= startOfToday && $0.status != .cancelled }
                        .sorted { $0.startAt < $1.startAt }
                    let newSelection = remaining.first?.id.uuidString

                    if selectedTimelineID == bookingIDToDelete.uuidString {
                        selectedTimelineID = newSelection
                    }

                    if case .edit(let editingID) = bookingEditorSession,
                       editingID == bookingIDToDelete {
                        bookingEditorSession = nil
                    }

                    pendingManualDeleteBookingID = nil
                }

                Button("Abbrechen", role: .cancel) {
                    pendingManualDeleteBookingID = nil
                }
            }
            .confirmationDialog(
                "Buchung von Reise entfernen?",
                isPresented: $showRemoveFromTripConfirmation,
                titleVisibility: .visible
            ) {
                Button("Entfernen", role: .destructive) {
                    guard let bookingID = pendingRemoveFromTripBookingID,
                          let booking = trip.bookings.first(where: { $0.id == bookingID }) else { return }
                    let fallbackTimelineID = sortedBookings.first(where: { $0.id != bookingID })?.id.uuidString
                    removeBookingFromTrip(booking, fallbackTimelineID: fallbackTimelineID)
                    pendingRemoveFromTripBookingID = nil
                }
                Button("Abbrechen", role: .cancel) {
                    pendingRemoveFromTripBookingID = nil
                }
            } message: {
                Text("Die Buchung wird der Reise entzogen und erscheint unter „Offene Buchungen“.")
            }
        } else {
            BookingDetailPanel(
                selectedTimelineItem: selectedTimelineItem,
                trip: trip,
                overlapCountsByBookingID: overlapCountsByBookingID,
                bookingEditorSession: $bookingEditorSession,
                selectedTimelineID: $selectedTimelineID,
                onEditGap: { payload in gapEditorPayload = payload },
                    gapPresentation: gapPresentation(for:),
                    onRequestManualDeleteBooking: { bookingID in
                        pendingManualDeleteBookingID = bookingID
                        showManualDeleteConfirmation = true
                    },
                    onRequestRemoveFromTrip: { bookingID in
                        guard let booking = trip.bookings.first(where: { $0.id == bookingID }) else { return }
                        requestRemoveBookingFromTrip(booking)
                    }
            )
            .navigationTitle(trip.title)
            .sheet(item: $gapEditorPayload) { payload in
                GapEditorSheet(
                    titleText: payload.title,
                    kind: payload.kind,
                    priceAmount: payload.priceAmount,
                    priceCurrencyCode: payload.priceCurrencyCode
                ) { newTitle, newKind, newPriceAmount, newCurrencyCode in
                    gapOverrides[payload.id] = GapOverride(title: newTitle, kind: newKind)

                    let currencyCode = newCurrencyCode ?? "EUR"
                    let fromBooking = sortedBookings.first(where: { $0.id == payload.fromBookingID })
                    let toBooking = sortedBookings.first(where: { $0.id == payload.toBookingID })

                    if let fromBooking, let toBooking {
                        if let existing = savedGapsByKey[payload.id] {
                            existing.titleOverride = newTitle
                            existing.kindRaw = newKind.rawValue
                            existing.gapStart = payload.gapStart
                            existing.gapEnd = payload.gapEnd
                            existing.fromBooking = fromBooking
                            existing.toBooking = toBooking
                            existing.trip = trip
                            existing.identityKey = payload.id
                            existing.priceAmount = newPriceAmount
                            existing.priceCurrencyCode = currencyCode
                        } else {
                            let g = SDGap(
                                trip: trip,
                                fromBooking: fromBooking,
                                toBooking: toBooking,
                                gapStart: payload.gapStart,
                                gapEnd: payload.gapEnd,
                                kindRaw: newKind.rawValue,
                                titleOverride: newTitle,
                                identityKey: payload.id,
                                priceAmount: newPriceAmount,
                                priceCurrencyCode: currencyCode,
                                suggestionStateRaw: "none"
                            )
                            modelContext.insert(g)
                        }
                        try? modelContext.save()
                    }

                    gapEditorPayload = nil
                }
            }
            .confirmationDialog(
                "Buchung wirklich löschen?",
                isPresented: $showManualDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Löschen", role: .destructive) {
                    guard let bookingIDToDelete = pendingManualDeleteBookingID else { return }

                    if let bookingToDelete = trip.bookings.first(where: { $0.id == bookingIDToDelete }) {
                        modelContext.delete(bookingToDelete)
                        try? modelContext.save()
                    }

                    let startOfToday = Calendar.current.startOfDay(for: Date())
                    let remaining = trip.bookings
                        .filter { $0.startAt >= startOfToday && $0.status != .cancelled }
                        .sorted { $0.startAt < $1.startAt }
                    let newSelection = remaining.first?.id.uuidString

                    if selectedTimelineID == bookingIDToDelete.uuidString {
                        selectedTimelineID = newSelection
                    }

                    if case .edit(let editingID) = bookingEditorSession,
                       editingID == bookingIDToDelete {
                        bookingEditorSession = nil
                    }

                    pendingManualDeleteBookingID = nil
                }

                Button("Abbrechen", role: .cancel) {
                    pendingManualDeleteBookingID = nil
                }
            }
            .confirmationDialog(
                "Buchung von Reise entfernen?",
                isPresented: $showRemoveFromTripConfirmation,
                titleVisibility: .visible
            ) {
                Button("Entfernen", role: .destructive) {
                    guard let bookingID = pendingRemoveFromTripBookingID,
                          let booking = trip.bookings.first(where: { $0.id == bookingID }) else { return }
                    let fallbackTimelineID = sortedBookings.first(where: { $0.id != bookingID })?.id.uuidString
                    removeBookingFromTrip(booking, fallbackTimelineID: fallbackTimelineID)
                    pendingRemoveFromTripBookingID = nil
                }
                Button("Abbrechen", role: .cancel) {
                    pendingRemoveFromTripBookingID = nil
                }
            } message: {
                Text("Die Buchung wird der Reise entzogen und erscheint unter „Offene Buchungen“.")
            }
        }
    }

    @ViewBuilder
    private func bookingsList(
        timelineItems: [TimelineItem],
        fallbackTimelineID: String?
    ) -> some View {
        // Keine SwiftUI-List/Table: deren Scroll-vs.-Tap-Erkennung verzögert Klicks
        // und lässt sie manchmal ausfallen. ScrollView + plain Button = sofortige Selektion.
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(timelineItems) { item in
                        Button {
                            selectedTimelineID = item.id
                        } label: {
                            TimelineRowLabel(
                                item: item,
                                overlapCountsByBookingID: overlapCountsByBookingID,
                                gapPresentation: gapPresentation(for:),
                                onEditGap: { payload in
                                    gapEditorPayload = payload
                                }
                            )
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                selectedTimelineID == item.id
                                    ? Color.accentColor.opacity(0.12)
                                    : Color.clear
                            )
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .id(item.id)
                        .contextMenu {
                            switch item {
                            case .booking(let booking):
                                Button("Bearbeiten") { editBooking(booking) }
                                Button("Buchung hinzufügen…") {
                                    startCreateBooking(
                                        prefillStart: nil,
                                        prefillEnd: nil,
                                        selectID: booking.id.uuidString
                                    )
                                }
                                if let urlString = booking.externalUrl,
                                   let url = URL(string: urlString),
                                   !urlString.hasPrefix("reisen://manual/") {
                                    Button("Buchung im Browser öffnen") {
                                        NSWorkspace.shared.open(url)
                                    }
                                }
                                Button(role: .destructive) {
                                    requestRemoveBookingFromTrip(booking)
                                } label: {
                                    Text("Von Reise entfernen…")
                                }

                                if ProviderID(rawValue: booking.providerRaw) == .manual {
                                    Button(role: .destructive) { requestDeleteManualBooking(booking) } label: {
                                        Text("Löschen…")
                                    }
                                }

                            case .gap(let gap):
                                let presentation = gapPresentation(for: gap)
                                let editPayload = TripDetailView.GapEditorPayload(
                                    id: presentation.key,
                                    title: presentation.displayTitle,
                                    kind: presentation.effectiveKind,
                                    priceAmount: presentation.priceAmount,
                                    priceCurrencyCode: presentation.priceCurrencyCode,
                                    gapStart: gap.gapStart,
                                    gapEnd: gap.gapEnd,
                                    fromBookingID: gap.fromBooking.id,
                                    toBookingID: gap.toBooking.id
                                )

                                Button("Lücke bearbeiten…") {
                                    selectTimelineID(item.id)
                                    gapEditorPayload = editPayload
                                }
                                Button("Buchung hinzufügen…") {
                                    startCreateBooking(
                                        prefillStart: gap.gapStart,
                                        prefillEnd: gap.gapEnd,
                                        selectID: item.id
                                    )
                                }
                            }
                        }

                        Divider()
                            .padding(.leading, 12)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onChange(of: selectedTimelineID) { _, newID in
                scrollBookingsList(to: newID, proxy: proxy)
            }
            .onAppear {
                scrollBookingsList(to: selectedTimelineID, proxy: proxy)
            }
        }
    }

    private func scrollBookingsList(to timelineID: String?, proxy: ScrollViewProxy) {
        guard let timelineID else { return }
        // LazyVStack: Zielzeile ggf. erst nach Layout-Pass vorhanden.
        Task { @MainActor in
            await Task.yield()
            withAnimation(.easeInOut(duration: 0.25)) {
                proxy.scrollTo(timelineID, anchor: .center)
            }
        }
    }

    private func timelineItems(gaps: [ComputedGap], bookings: [SDBooking]) -> [TimelineItem] {
        let bookingItems = bookings.map { TimelineItem.booking($0) }
        let gapItems = gaps.map { TimelineItem.gap($0) }

        return (bookingItems + gapItems).sorted { lhs, rhs in
            if lhs.startDate == rhs.startDate {
                // Bei identischem Start: echte Buchung vor Lücke.
                switch (lhs, rhs) {
                case (.booking, .gap): return true
                case (.gap, .booking): return false
                default: return lhs.id < rhs.id
                }
            }
            return lhs.startDate < rhs.startDate
        }
    }

    private func gapKey(for gap: ComputedGap) -> String {
        let fromID = gap.fromBooking.id.uuidString
        let toID = gap.toBooking.id.uuidString
        let start = Int(gap.gapStart.timeIntervalSince1970)
        let end = Int(gap.gapEnd.timeIntervalSince1970)
        return "\(fromID)|\(toID)|\(start)|\(end)"
    }

    private func defaultGapTitle(for gap: ComputedGap) -> String {
        switch gap.kind {
        case .lodging:
            return "Private Übernachtung"
        case .transport:
            return "Zwischen-Transport"
        case .both:
            return "Lücke"
        }
    }

    private func gapPresentation(for gap: ComputedGap) -> GapPresentation {
        let key = gapKey(for: gap)
        let override = gapOverrides[key]
        let displayTitle = override?.title ?? defaultGapTitle(for: gap)
        let effectiveKind = override?.kind ?? gap.kind
        let savedGap = savedGapsByKey[key]

        let priceAmount = savedGap?.priceAmount
        let priceCurrencyCode = savedGap?.priceCurrencyCode
        let priceText: String? = {
            guard let priceAmount else { return nil }
            let currencyCode = priceCurrencyCode ?? "EUR"
            return formatCurrencyAmount(priceAmount, currencyCode: currencyCode)
        }()

        return GapPresentation(
            key: key,
            displayTitle: displayTitle,
            effectiveKind: effectiveKind,
            priceAmount: priceAmount,
            priceCurrencyCode: priceCurrencyCode,
            priceText: priceText
        )
    }

    @ViewBuilder
    private var tripOverviewSection: some View {
        // Kompakte Einzeiler — kein LabeledContent/NSView (das blähte die Übersicht auf).
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 16) {
                overviewFact(label: "Zeitraum", value: dateRange)
                overviewFact(label: "Preis", value: tripTotalPriceText)
                if let destination = trip.destination, !destination.isEmpty {
                    overviewFact(label: "Ziel", value: destination)
                }
                Spacer(minLength: 0)
            }
            if let notes = trip.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func overviewFact(label: String, value: String) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.medium))
                .textSelection(.enabled)
                .lineLimit(1)
        }
    }

    private var dateRange: String {
        let start = trip.startDate.formatted(date: .abbreviated, time: .omitted)
        let end = trip.endDate.formatted(date: .abbreviated, time: .omitted)
        return "\(start) – \(end)"
    }

    private func openBookingsCandidates() -> [SDBooking] {
        allBookings.filter { isOpenBookingCandidate($0, for: trip) }
    }
}

private enum TimelineItem: Identifiable {
    case booking(SDBooking)
    case gap(ComputedGap)

    var id: String {
        switch self {
        case .booking(let booking):
            return booking.id.uuidString
        case .gap(let gap):
            let fromID = gap.fromBooking.id.uuidString
            let toID = gap.toBooking.id.uuidString
            let start = Int(gap.gapStart.timeIntervalSince1970)
            let end = Int(gap.gapEnd.timeIntervalSince1970)
            return "gap|\(fromID)|\(toID)|\(start)|\(end)"
        }
    }

    var startDate: Date {
        switch self {
        case .booking(let booking):
            return booking.startAt
        case .gap(let gap):
            return gap.gapStart
        }
    }
}

private enum TimelineRowDisplayMode {
    case summary
    case details
}

private struct GapPresentation {
    let key: String
    let displayTitle: String
    let effectiveKind: GapKind
    let priceAmount: Double?
    let priceCurrencyCode: String?
    let priceText: String?
}

private struct TimelineRowLabel: View {
    let item: TimelineItem
    let overlapCountsByBookingID: [UUID: Int]
    let gapPresentation: (ComputedGap) -> GapPresentation
    let onEditGap: (TripDetailView.GapEditorPayload) -> Void

    var body: some View {
        switch item {
        case .booking(let booking):
            let overlapCount = overlapCountsByBookingID[booking.id] ?? 0
            BookingRow(
                booking: booking,
                displayMode: .summary,
                isOverlapping: overlapCount > 0,
                overlapCount: overlapCount,
                onSelect: nil
            )

        case .gap(let gap):
            let presentation = gapPresentation(gap)

            let editPayload = TripDetailView.GapEditorPayload(
                id: presentation.key,
                title: presentation.displayTitle,
                kind: presentation.effectiveKind,
                priceAmount: presentation.priceAmount,
                priceCurrencyCode: presentation.priceCurrencyCode,
                gapStart: gap.gapStart,
                gapEnd: gap.gapEnd,
                fromBookingID: gap.fromBooking.id,
                toBookingID: gap.toBooking.id
            )

            GapRow(
                gap: gap,
                displayMode: .summary,
                displayTitle: presentation.displayTitle,
                effectiveKind: presentation.effectiveKind,
                priceText: presentation.priceText,
                onEdit: { onEditGap(editPayload) },
                onSelect: nil
            )
        }
    }
}

private struct ContentHeightReader: View {
    var onChange: (CGFloat) -> Void

    var body: some View {
        GeometryReader { geometry in
            Color.clear
                .onAppear { onChange(geometry.size.height) }
                .onChange(of: geometry.size.height) { _, height in
                    onChange(height)
                }
        }
    }
}

private struct BookingDetailPanel: View {
    let selectedTimelineItem: TimelineItem?
    let trip: SDTrip
    let overlapCountsByBookingID: [UUID: Int]
    @Binding var bookingEditorSession: BookingEditorSession?
    @Binding var selectedTimelineID: String?
    let onEditGap: (TripDetailView.GapEditorPayload) -> Void
    let gapPresentation: (ComputedGap) -> GapPresentation
    let onRequestManualDeleteBooking: (UUID) -> Void
    let onRequestRemoveFromTrip: (UUID) -> Void
    var onContentHeightChange: ((CGFloat) -> Void)? = nil

    @Environment(\.modelContext) private var modelContext
    @State private var bookingEditorDraft: BookingEditorDraft?

    private var selectedBooking: SDBooking? {
        guard case .booking(let booking) = selectedTimelineItem else { return nil }
        return booking
    }

    private var selectedBookingID: UUID? { selectedBooking?.id }

    private var isEditing: Bool { bookingEditorSession != nil }

    private var bookingStatusBarHeight: CGFloat { 32 }

    var body: some View {
        Group {
            if isEditing, let draftBinding = draftBinding {
                BookingEditorForm(
                    title: editorTitle,
                    showsSyncOverwriteHint: showsSyncOverwriteHint,
                    draft: draftBinding,
                    providerReadOnly: providerReadOnly,
                    onCancel: { clearEditor() },
                    onSave: { try saveEditor() }
                )
            } else {
                ZStack(alignment: .bottom) {
                    detailScrollContent
                        .padding(.bottom, bookingStatusBarHeight)

                    if let synced = selectedBooking?.lastSyncedAt {
                        bookingStatusBar(synced: synced)
                            .frame(height: bookingStatusBarHeight)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear { syncDraftFromSession(resetDraft: false) }
        .onChange(of: bookingEditorSession) { _, _ in
            syncDraftFromSession(resetDraft: true)
        }
        .onChange(of: selectedBookingID) { _, newID in
            guard case .edit(let editingID) = bookingEditorSession else { return }
            guard newID != editingID else { return }
            clearEditor()
        }
        .onChange(of: trip.id) { _, _ in
            clearEditor()
        }
    }

    private func syncDraftFromSession(resetDraft: Bool) {
        switch bookingEditorSession {
        case .create(let prefillStart, let prefillEnd):
            guard resetDraft || bookingEditorDraft == nil else { return }
            bookingEditorDraft = BookingEditorDraft.createDefault(
                tripStartDate: trip.startDate,
                prefillStart: prefillStart,
                prefillEnd: prefillEnd
            )
        case .edit(let bookingID):
            guard resetDraft || bookingEditorDraft == nil else { return }
            if let booking = selectedBooking, booking.id == bookingID {
                bookingEditorDraft = BookingEditorDraft.fromExisting(booking)
            } else {
                bookingEditorDraft = nil
            }
        case nil:
            bookingEditorDraft = nil
        }
    }

    private var editorTitle: String {
        switch bookingEditorSession {
        case .create(_, _): return "Buchung hinzufügen"
        case .edit: return "Buchung bearbeiten"
        case nil: return "Buchung"
        }
    }

    private var showsSyncOverwriteHint: Bool {
        guard case .edit = bookingEditorSession,
              let booking = selectedBooking else { return false }
        return booking.provider != .manual
    }

    private var providerReadOnly: Bool {
        switch bookingEditorSession {
        case .edit: return true
        default: return false
        }
    }

    private var draftBinding: Binding<BookingEditorDraft>? {
        guard bookingEditorDraft != nil else { return nil }
        return Binding(
            get: { bookingEditorDraft! },
            set: { bookingEditorDraft = $0 }
        )
    }

    private var detailScrollContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Divider()

                if let selectedTimelineItem {
                    Group {
                        switch selectedTimelineItem {
                        case .booking(let booking):
                            BookingDetailContent(
                                booking: booking,
                                isOverlapping: (overlapCountsByBookingID[booking.id] ?? 0) > 0,
                                overlapCount: overlapCountsByBookingID[booking.id] ?? 0,
                                onEditBooking: { bookingEditorSession = .edit(bookingID: booking.id) },
                                onRequestManualDeleteBooking: onRequestManualDeleteBooking,
                                onRequestRemoveFromTrip: onRequestRemoveFromTrip
                            )
                        case .gap(let gap):
                            let presentation = gapPresentation(gap)

                            GapRow(
                                gap: gap,
                                displayMode: .details,
                                displayTitle: presentation.displayTitle,
                                effectiveKind: presentation.effectiveKind,
                                priceText: presentation.priceText,
                                onEdit: {
                                    onEditGap(
                                        TripDetailView.GapEditorPayload(
                                            id: presentation.key,
                                            title: presentation.displayTitle,
                                            kind: presentation.effectiveKind,
                                            priceAmount: presentation.priceAmount,
                                            priceCurrencyCode: presentation.priceCurrencyCode,
                                            gapStart: gap.gapStart,
                                            gapEnd: gap.gapEnd,
                                            fromBookingID: gap.fromBooking.id,
                                            toBookingID: gap.toBooking.id
                                        )
                                    )
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text("Buchung in der Liste auswählen, um Details anzuzeigen.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 14)
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .fixedSize(horizontal: false, vertical: true)
            .background(.ultraThinMaterial)
            .background {
                ContentHeightReader { height in
                    onContentHeightChange?(height)
                }
            }
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func clearEditor() {
        bookingEditorSession = nil
        bookingEditorDraft = nil
    }

    private func saveEditor() throws {
        guard let draft = bookingEditorDraft else { return }
        switch bookingEditorSession {
        case .create(_, _):
            let newID = try BookingEditorDraft.createBooking(
                from: draft,
                trip: trip,
                in: modelContext
            )
            selectedTimelineID = newID.uuidString
            clearEditor()
        case .edit:
            guard let booking = selectedBooking else { return }
            try draft.apply(to: booking, in: modelContext)
            clearEditor()
        case nil:
            break
        }
    }

    private func bookingStatusBar(synced: Date) -> some View {
        HStack(spacing: 8) {
            Text("Zuletzt synchronisiert")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text(synced.formatted(date: .abbreviated, time: .shortened))
                .font(.caption2)
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .background(.bar)
    }
}

/// Vollständige Buchungsdetails für das untere Panel (alle persistierten Felder).
private struct BookingDetailContent: View {
    let booking: SDBooking
    let isOverlapping: Bool
    let overlapCount: Int
    let onEditBooking: (() -> Void)?
    let onRequestManualDeleteBooking: (UUID) -> Void
    let onRequestRemoveFromTrip: (UUID) -> Void

    private var priceText: String {
        let details = booking.rateDetails
        guard let amount = details?.totalPriceAmount else { return "k.A." }
        return formatCurrencyAmount(amount, currencyCode: details?.totalPriceCurrency)
    }

    private var hotelTimeZone: TimeZone {
        if let offsetSeconds = booking.hotelOffsetSeconds {
            return TimeZone(secondsFromGMT: offsetSeconds) ?? .current
        }
        let deadlineOffset = booking.cancellationDeadlines.compactMap(\.hotelOffsetSeconds).first
        if let deadlineOffset { return TimeZone(secondsFromGMT: deadlineOffset) ?? .current }
        return TimeZone(secondsFromGMT: 0) ?? .current
    }

    private func displayTimeZone(forStartOf booking: SDBooking) -> TimeZone {
        switch booking.bookingType {
        case .flight, .ferry:
            if let offset = booking.flightDepartureOffsetSeconds {
                return TimeZone(secondsFromGMT: offset) ?? .current
            }
            return .current
        case .hotel, .other:
            return hotelTimeZone
        }
    }

    private func displayTimeZone(forEndOf booking: SDBooking) -> TimeZone {
        switch booking.bookingType {
        case .flight, .ferry:
            if let offset = booking.flightArrivalOffsetSeconds {
                return TimeZone(secondsFromGMT: offset) ?? .current
            }
            return .current
        case .hotel, .other:
            return hotelTimeZone
        }
    }

    private func formatDate(_ date: Date, format: String, timeZone: TimeZone) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "de_DE_POSIX")
        df.timeZone = timeZone
        df.dateFormat = format
        return df.string(from: date)
    }

    private func localizedBoardLabel(for boardType: BookingBoardType) -> String? {
        switch boardType {
        case .roomOnly: return "Nur Zimmer"
        case .breakfastIncluded: return "Frühstück"
        case .halfBoard: return "Halbpension"
        case .fullBoard: return "Vollpension"
        case .unknown: return nil
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(booking.title ?? booking.bookingType.rawValue.capitalized)
                        .font(.headline)
                        .textSelection(.enabled)
                    if isOverlapping {
                        Text(overlapCount > 0 ? "Überschneidung (+\(overlapCount))" : "Überschneidung")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 2) {
                    ProviderLogo(providerID: booking.provider)
                    Text(booking.bookingType.rawValue.capitalized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(priceText)
                        .font(.subheadline.weight(.semibold))
                }
            }

            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 160), spacing: 8, alignment: .leading),
            ], alignment: .leading, spacing: 6) {
                detailRow("Status", booking.status.rawValue)
                if let from = booking.locationFrom, !from.isEmpty {
                    detailRow("Von", from)
                }
                if let to = booking.locationTo, !to.isEmpty {
                    detailRow("Nach", to)
                }
                if booking.bookingType == .hotel {
                    detailRow(
                        "Start",
                        HotelStayDate.format(
                            booking.startAt,
                            dateFormat: "d.M.yyyy",
                            legacyHotelOffsetSeconds: booking.hotelOffsetSeconds
                        )
                    )
                    detailRow(
                        "Ende",
                        HotelStayDate.format(
                            booking.endAt,
                            dateFormat: "d.M.yyyy",
                            legacyHotelOffsetSeconds: booking.hotelOffsetSeconds
                        )
                    )
                } else {
                    detailRow(
                        "Start",
                        formatDate(
                            booking.startAt,
                            format: "d.M.yyyy HH:mm",
                            timeZone: displayTimeZone(forStartOf: booking)
                        )
                    )
                    detailRow(
                        "Ende",
                        formatDate(
                            booking.endAt,
                            format: "d.M.yyyy HH:mm",
                            timeZone: displayTimeZone(forEndOf: booking)
                        )
                    )
                }
                if let checkIn = booking.hotelCheckInMinutes {
                    detailRow("Check-in", minutesToHHmm(checkIn))
                }
                if let checkOut = booking.hotelCheckOutMinutes {
                    detailRow("Check-out", minutesToHHmm(checkOut))
                }
            }

            if let rate = booking.rateDetails {
                Divider()
                Text("Preis / Tarif")
                    .font(.subheadline.weight(.semibold))
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 160), spacing: 8, alignment: .leading),
                ], alignment: .leading, spacing: 6) {
                    if let amount = rate.totalPriceAmount {
                        detailRow("Preis", formatCurrencyAmount(amount, currencyCode: rate.totalPriceCurrency))
                    }
                    if let currency = rate.totalPriceCurrency, !currency.isEmpty {
                        detailRow("Währung", currency)
                    }
                    if rate.roomItems.isEmpty, let room = rate.roomCategory, !room.isEmpty {
                        detailRow("Zimmerkategorie", room)
                    }
                    if let breakfast = rate.includedBreakfast {
                        detailRow("Frühstück", breakfast ? "ja" : "nein")
                    }
                    if let guests = rate.guestCount {
                        detailRow("Gäste", "\(guests)")
                    }
                    if let rooms = rate.roomCount {
                        detailRow("Zimmer", "\(rooms)")
                    }
                    if let airline = rate.airline, !airline.isEmpty {
                        detailRow("Airline", airline)
                    }
                    if !booking.passengers.isEmpty {
                        // HIG: Unwichtige Titel (MR/MS/Mx) nicht anzeigen, nur Vor-/Nachname.
                        let names = booking.passengers.compactMap { pax -> String? in
                            let parts = [pax.givenName, pax.familyName]
                                .compactMap { part -> String? in
                                    let trimmed = part?.trimmingCharacters(in: .whitespacesAndNewlines)
                                    return (trimmed?.isEmpty == false) ? trimmed : nil
                                }
                            let fullName = parts.joined(separator: " ")
                            return fullName.isEmpty ? nil : fullName
                        }
                        detailRow("Passagiere", names.joined(separator: ", "))
                    } else if let passengers = rate.passengerCount {
                        detailRow("Passagiere", "\(passengers)")
                    }
                    if let baggage = rate.baggageInfoRaw, !baggage.isEmpty {
                        detailRow("Gepäck", baggage)
                    }
                    if let rawBoardType = rate.boardTypeRaw,
                       !rawBoardType.isEmpty,
                       let boardType = BookingBoardType(rawValue: rawBoardType),
                       let boardLabel = localizedBoardLabel(for: boardType) {
                        detailRow("Verpflegung", boardLabel)
                    }
                    if let parsed = rate.lastParsedAt {
                        detailRow("Tarif gelesen", parsed.formatted(date: .abbreviated, time: .shortened))
                    }
                }

                if !rate.roomItems.isEmpty {
                    Divider()
                    Text("Zimmer / Positionen")
                        .font(.subheadline.weight(.semibold))

                    ForEach(rate.roomItems.sorted(by: { ($0.sortIndex ?? 0) < ($1.sortIndex ?? 0) })) { item in
                        VStack(alignment: .leading, spacing: 3) {
                            if let category = item.category, !category.isEmpty {
                                Text(category)
                                    .font(.caption.weight(.medium))
                            }
                            if let code = item.confirmationCode, !code.isEmpty {
                                Text("Buchungsnr.: \(code)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            if let guest = item.guestSummary, !guest.isEmpty {
                                Text(guest)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            if let amount = item.priceAmount {
                                let currency = item.priceCurrency ?? rate.totalPriceCurrency
                                detailRow("Einzelpreis", formatCurrencyAmount(amount, currencyCode: currency))
                            }
                        }
                    }
                }
            }

            if !booking.cancellationDeadlines.isEmpty {
                Divider()
                Text("Stornierung")
                    .font(.subheadline.weight(.semibold))
                ForEach(booking.cancellationDeadlines.sorted(by: { $0.deadlineAt < $1.deadlineAt }), id: \.id) { deadline in
                    let tz = deadline.hotelOffsetSeconds.flatMap { TimeZone(secondsFromGMT: $0) } ?? hotelTimeZone
                    VStack(alignment: .leading, spacing: 2) {
                        Text(formatDate(deadline.deadlineAt, format: "d.M.yyyy HH:mm", timeZone: tz))
                            .font(.caption.weight(.medium))
                        HStack(spacing: 8) {
                            Text(deadline.isFreeCancellation ? "Kostenlos" : "Kostenpflichtig")
                                .font(.caption2)
                                .foregroundStyle(deadline.isFreeCancellation ? .green : .secondary)
                            if let fee = deadline.cancellationFeeAmount {
                                Text(formatCurrencyAmount(fee, currencyCode: booking.rateDetails?.totalPriceCurrency))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            if deadline.isStrict {
                                Text("strikt")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        if let policy = deadline.policyText, !policy.isEmpty {
                            Text(policy)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }

            if let urlString = booking.externalUrl,
               let url = URL(string: urlString),
               !urlString.hasPrefix("reisen://manual/") {
                Divider()
                Link("Buchung im Browser öffnen", destination: url)
                    .font(.caption)
            }

            if let onEditBooking {
                Button("Bearbeiten") {
                    onEditBooking()
                }
                .buttonStyle(.link)
                .padding(.top, 4)
                .help("Diese Buchung bearbeiten")
            }

            if ProviderID(rawValue: booking.providerRaw) == .manual {
                Button(role: .destructive) {
                    onRequestManualDeleteBooking(booking.id)
                } label: {
                    Text("Löschen…")
                }
                .buttonStyle(.link)
                .padding(.top, 4)
                .help("Diese manuelle Buchung unwiderruflich löschen")
            }

            Button(role: .destructive) {
                onRequestRemoveFromTrip(booking.id)
            } label: {
                Text("Von Reise entfernen…")
            }
            .buttonStyle(.link)
            .padding(.top, 4)
            .help("Diese Buchung aus der Reise lösen und unter „Offene Buchungen“ anzeigen")
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

private struct BookingRow: View {
    let booking: SDBooking
    let displayMode: TimelineRowDisplayMode
    let isOverlapping: Bool
    let overlapCount: Int
    var onSelect: (() -> Void)? = nil

    private var bookingPriceText: String {
        let details = booking.rateDetails
        guard let amount = details?.totalPriceAmount else { return "k.A." }
        return formatCurrencyAmount(amount, currencyCode: details?.totalPriceCurrency)
    }

    private func bookingTypeTitle(_ booking: SDBooking) -> String {
        booking.bookingType.rawValue.capitalized
    }

    private var hotelTimeZone: TimeZone {
        if let offsetSeconds = booking.hotelOffsetSeconds {
            return TimeZone(secondsFromGMT: offsetSeconds) ?? .current
        }
        // Fallback: wenn der Booking-Offset noch nicht persistiert ist.
        let deadlineOffsetSeconds = booking.cancellationDeadlines.compactMap(\.hotelOffsetSeconds).first
        if let deadlineOffsetSeconds { return TimeZone(secondsFromGMT: deadlineOffsetSeconds) ?? .current }
        // Default: Opodo/Provider-Offsets kommen in der Regel als "Wall-Clock UTC" (Offset 0).
        return TimeZone(secondsFromGMT: 0) ?? .current
    }

    private func cancellationCopyText(
        futureDeadlinesForDisplay: [SDCancellationDeadline],
        hasFutureFreeCancellation: Bool
    ) -> String {
        var lines: [String] = []

        // Nur eine Lock-Zeile, nicht mehrfach.
        if !hasFutureFreeCancellation {
            lines.append("Fix (nicht mehr kostenlos stornierbar)")
        }

        for deadline in futureDeadlinesForDisplay {
            let tz = timeZone(forDeadline: deadline)
            if deadline.isFreeCancellation {
                lines.append(
                    "Kostenlos stornierbar bis \(formatOrtszeit(deadline.deadlineAt, dateFormat: "d.M. HH:mm", timeZone: tz))"
                )
            } else {
                let paidText = (deadline.policyText?.isEmpty == false)
                    ? deadline.policyText!
                    : "Kostenpflichtig stornierbar bis \(formatOrtszeit(deadline.deadlineAt, dateFormat: "d.M. HH:mm", timeZone: tz))"
                lines.append(paidText)
            }
        }

        return lines.joined(separator: "\n")
    }

    private func computeFutureDeadlinesForDisplay(now: Date = Date()) -> [SDCancellationDeadline] {
        let service = CancellationDeadlineDisplayService()
        let domainDeadlines = booking.cancellationDeadlines.map(DomainMapper.deadline(from:))
        let filteredDomainDeadlines = service.deadlinesForDisplay(domainDeadlines, now: now)
        let keepIDs = Set(filteredDomainDeadlines.map(\.id))
        return booking.cancellationDeadlines.filter { keepIDs.contains($0.id) }
    }

    private func bookingTimeCopyText() -> String {
        switch booking.bookingType {
        case .hotel:
            let checkInDate = HotelStayDate.format(
                booking.startAt,
                dateFormat: "d.M.",
                legacyHotelOffsetSeconds: booking.hotelOffsetSeconds
            )
            let checkOutDate = HotelStayDate.format(
                booking.endAt,
                dateFormat: "d.M.",
                legacyHotelOffsetSeconds: booking.hotelOffsetSeconds
            )
            let checkInTime = booking.hotelCheckInMinutes.map(minutesToHHmm) ?? "—"
            let checkOutTime = booking.hotelCheckOutMinutes.map(minutesToHHmm) ?? "—"

            return "Check-in: \(checkInDate) ab \(checkInTime) (\(hotelLocationLabel))\nCheck-out: \(checkOutDate) bis \(checkOutTime) (\(hotelLocationLabel))"

        case .flight, .ferry:
            let departureOffsetSeconds = booking.flightDepartureOffsetSeconds
            let arrivalOffsetSeconds = booking.flightArrivalOffsetSeconds

            let departureTZ = (departureOffsetSeconds.flatMap { TimeZone(secondsFromGMT: $0) }) ?? .current
            let arrivalTZ = (arrivalOffsetSeconds.flatMap { TimeZone(secondsFromGMT: $0) }) ?? .current

            let tzHint: String = {
                if departureOffsetSeconds == nil || arrivalOffsetSeconds == nil { return " (Zeitzone noch nicht ermittelt)" }
                return ""
            }()

            let departure = formatOrtszeit(
                booking.startAt,
                dateFormat: "d.M. HH:mm",
                timeZone: departureTZ
            )
            let arrival = formatOrtszeit(
                booking.endAt,
                dateFormat: "d.M. HH:mm",
                timeZone: arrivalTZ
            )

            return "Abflug: \(departure) (\(flightOriginLabel))\(tzHint)\nAnkunft: \(arrival) (\(flightDestinationLabel))"

        case .other:
            return "\(booking.startAt.formatted(date: .abbreviated, time: .shortened)) – \(booking.endAt.formatted(date: .abbreviated, time: .shortened))"
        }
    }

    /// Listen-Zusammenfassung: Storno-Zeilen mit Icons/Urgency-Farben (wie früher im Attributed-Text).
    private struct SummaryStornoLine: Identifiable {
        let id: String
        let systemImage: String
        let text: String
        let color: Color
    }

    private func bookingSummaryStornoLines(now: Date = Date()) -> [SummaryStornoLine] {
        guard !booking.cancellationDeadlines.isEmpty else { return [] }

        let domainDeadlines = booking.cancellationDeadlines.map(DomainMapper.deadline(from:))
        let service = CancellationDeadlineDisplayService()
        let summaryLines = service.summaryLines(
            deadlines: domainDeadlines,
            hotelTimeZone: hotelTimeZone,
            now: now
        )

        return summaryLines.map { summaryLine in
            let color: Color = {
                switch summaryLine.kind {
                case .fix, .paid:
                    return .secondary
                case .free:
                    guard let urgency = summaryLine.urgency else { return .secondary }
                    switch urgency {
                    case .ok: return .green
                    case .warning: return .orange
                    case .critical: return .red
                    case .fix: return .secondary
                    }
                }
            }()

            return SummaryStornoLine(
                id: summaryLine.id.uuidString,
                systemImage: summaryLine.systemImageName,
                text: summaryLine.text,
                color: color
            )
        }
    }

    /// Start-/Enddatum für die Listenzeile (ohne Check-in/Check-out-Uhrzeiten).
    private func bookingSummaryDateRangeText() -> String {
        switch booking.bookingType {
        case .hotel:
            let start = HotelStayDate.format(
                booking.startAt,
                dateFormat: "d.M.",
                legacyHotelOffsetSeconds: booking.hotelOffsetSeconds
            )
            let end = HotelStayDate.format(
                booking.endAt,
                dateFormat: "d.M.",
                legacyHotelOffsetSeconds: booking.hotelOffsetSeconds
            )
            return "\(start) – \(end) (\(hotelLocationLabel))"
        case .flight, .ferry:
            return bookingTimeCopyText()
        case .other:
            return "\(booking.startAt.formatted(date: .abbreviated, time: .omitted)) – \(booking.endAt.formatted(date: .abbreviated, time: .omitted))"
        }
    }

    private func bookingFullCopyText(now: Date) -> String {
        var parts: [String] = []

        parts.append(booking.title ?? bookingTypeTitle(booking))
        parts.append(bookingTypeTitle(booking))
        parts.append("Preis: \(bookingPriceText)")

        if isOverlapping {
            parts.append(overlapCount > 0 ? "Überschneidung (+\(overlapCount))" : "Überschneidung")
        }

        parts.append(bookingTimeCopyText())

        // Für Copy müssen auch Fälle abgedeckt werden, in denen es Stornofristen gibt,
        // aber keine zukünftigen Freistornierungen mehr (UI zeigt dann "Fix ...").
        if !booking.cancellationDeadlines.isEmpty {
            let futureDeadlinesForDisplay = computeFutureDeadlinesForDisplay(now: now)
            let hasFutureFreeCancellation = futureDeadlinesForDisplay.contains { $0.isFreeCancellation }
            parts.append(cancellationCopyText(
                futureDeadlinesForDisplay: futureDeadlinesForDisplay,
                hasFutureFreeCancellation: hasFutureFreeCancellation
            ))
        }

        return parts.joined(separator: "\n")
    }

    private func bookingAttributedDisplayText(now: Date) -> AttributedString {
        let ns = NSMutableAttributedString()
        appendHeaderAttributed(to: ns)
        appendTimeBlockAttributed(to: ns)
        appendCancellationBlockAttributed(to: ns, now: now)
        trimFinalNewline(from: ns)
        return AttributedString(ns)
    }

    private func appendHeaderAttributed(to ns: NSMutableAttributedString) {
        let headlineFont = NSFont.preferredFont(forTextStyle: .headline)
        let caption2Font = NSFont.preferredFont(forTextStyle: .caption2)

        let secondary = NSColor.secondaryLabelColor
        let orange = NSColor.systemOrange

        let title = booking.title ?? booking.bookingType.rawValue.capitalized
        ns.append(NSAttributedString(string: title, attributes: [
            .font: headlineFont,
            .foregroundColor: secondary
        ]))

        if isOverlapping {
            let overlapText = overlapCount > 0 ? "Überschneidung (+\(overlapCount))" : "Überschneidung"
            ns.append(NSAttributedString(string: "  \(overlapText)", attributes: [
                .font: caption2Font,
                .foregroundColor: orange
            ]))
        }

        ns.append(NSAttributedString(string: "\n"))
    }

    private func appendTimeBlockAttributed(to ns: NSMutableAttributedString) {
        let subheadlineFont = NSFont.preferredFont(forTextStyle: .subheadline)
        let secondary = NSColor.secondaryLabelColor

        let timeText = bookingTimeCopyText()
        let lines = timeText.components(separatedBy: "\n")
        for line in lines {
            ns.append(NSAttributedString(string: line, attributes: [
                .font: subheadlineFont,
                .foregroundColor: secondary
            ]))
            ns.append(NSAttributedString(string: "\n"))
        }
    }

    private func appendCancellationBlockAttributed(to ns: NSMutableAttributedString, now: Date) {
        guard displayMode == .details, !booking.cancellationDeadlines.isEmpty else { return }

        let captionFont = NSFont.preferredFont(forTextStyle: .caption1)
        let secondary = NSColor.secondaryLabelColor
        let orange = NSColor.systemOrange
        let green = NSColor.systemGreen
        let red = NSColor.systemRed

        let futureDeadlinesForDisplay = computeFutureDeadlinesForDisplay(now: now)
        if futureDeadlinesForDisplay.isEmpty {
            appendIconLine(
                to: ns,
                systemName: "lock.fill",
                text: "Fix (nicht mehr kostenlos stornierbar)",
                font: captionFont,
                color: secondary
            )
            return
        }

        let hasFutureFreeCancellation = futureDeadlinesForDisplay.contains { $0.isFreeCancellation }
        let urgencyService = CancellationUrgencyService()

        if !hasFutureFreeCancellation {
            appendIconLine(
                to: ns,
                systemName: "lock.fill",
                text: "Fix (nicht mehr kostenlos stornierbar)",
                font: captionFont,
                color: secondary
            )
        }

        for deadline in futureDeadlinesForDisplay {
            appendCancellationDeadlineLine(
                to: ns,
                deadline: deadline,
                now: now,
                urgencyService: urgencyService,
                font: captionFont,
                secondary: secondary,
                orange: orange,
                green: green,
                red: red
            )
        }
    }

    private func appendCancellationDeadlineLine(
        to ns: NSMutableAttributedString,
        deadline: SDCancellationDeadline,
        now: Date,
        urgencyService: CancellationUrgencyService,
        font: NSFont,
        secondary: NSColor,
        orange: NSColor,
        green: NSColor,
        red: NSColor
    ) {
        if deadline.isFreeCancellation {
            let urgency = urgencyService.urgency(for: DomainMapper.deadline(from: deadline), now: now)
            let color: NSColor = {
                switch urgency {
                case .ok: return green
                case .warning: return orange
                case .critical: return red
                case .fix: return secondary
                }
            }()

            appendIconLine(
                to: ns,
                systemName: "checkmark.circle.fill",
                text: "Kostenlos stornierbar bis \(formatOrtszeit(deadline.deadlineAt, dateFormat: "d.M. HH:mm", timeZone: timeZone(forDeadline: deadline)))",
                font: font,
                color: color
            )
        } else {
            let paidText = (deadline.policyText?.isEmpty == false)
                ? deadline.policyText!
                : "Kostenpflichtig stornierbar bis \(formatOrtszeit(deadline.deadlineAt, dateFormat: "d.M. HH:mm", timeZone: timeZone(forDeadline: deadline)))"

            appendIconLine(
                to: ns,
                systemName: "tag.fill",
                text: paidText,
                font: font,
                color: secondary
            )
        }
    }

    private func appendIconLine(
        to ns: NSMutableAttributedString,
        systemName: String,
        text: String,
        font: NSFont,
        color: NSColor,
        iconSize: CGFloat = 12
    ) {
        appendIcon(
            to: ns,
            systemName: systemName,
            color: color,
            size: iconSize
        )

        ns.append(NSAttributedString(string: " ", attributes: [
            .font: font,
            .foregroundColor: color
        ]))
        ns.append(NSAttributedString(string: text, attributes: [
            .font: font,
            .foregroundColor: color
        ]))
        ns.append(NSAttributedString(string: "\n"))
    }

    private func appendIcon(
        to ns: NSMutableAttributedString,
        systemName: String,
        color: NSColor,
        size: CGFloat
    ) {
        let config = NSImage.SymbolConfiguration(pointSize: size, weight: .regular)
        guard let image = NSImage(systemSymbolName: systemName, accessibilityDescription: nil)?
            .withSymbolConfiguration(config) else { return }

        // Template-Rendering, damit das Symbol durch Textfarbe/Attributes mitgefärbt werden kann.
        image.isTemplate = true

        let attachment = NSTextAttachment()
        attachment.image = image
        attachment.bounds = CGRect(x: 0, y: -1, width: size, height: size)

        let iconString = NSAttributedString(attachment: attachment)
        ns.append(iconString)

        if iconString.length > 0 {
            let range = NSRange(location: ns.length - iconString.length, length: iconString.length)
            ns.addAttributes([.foregroundColor: color], range: range)
        }
    }

    private func trimFinalNewline(from ns: NSMutableAttributedString) {
        while ns.string.hasSuffix("\n") && ns.length > 0 {
            ns.deleteCharacters(in: NSRange(location: ns.length - 1, length: 1))
        }
    }

    /// Storno: Deadline-Offset aus Provider-ISO (Opodo `-00:00` → 1.8. 22:00, nicht CEST 2.8. 00:00).
    private func timeZone(forDeadline deadline: SDCancellationDeadline) -> TimeZone {
        if let offsetSeconds = deadline.hotelOffsetSeconds {
            return TimeZone(secondsFromGMT: offsetSeconds) ?? hotelTimeZone
        }
        return hotelTimeZone
    }

    private var hotelLocationLabel: String {
        let label = booking.locationTo ?? booking.locationFrom ?? ""
        return label.isEmpty ? "Ziel" : label
    }

    private var flightOriginLabel: String {
        let label = booking.locationFrom ?? ""
        return label.isEmpty ? "Abflugort" : label
    }

    private var flightDestinationLabel: String {
        let label = booking.locationTo ?? ""
        return label.isEmpty ? "Ankunftsort" : label
    }

    var body: some View {
        // Summary: reines SwiftUI (kein NSTextView/onTapGesture — sonst verzögerte Listen-Klicks).
        Group {
            if displayMode == .summary {
                bookingSummaryBody
            } else {
                bookingDetailsBody
            }
        }
        .padding(.vertical, 2)
    }

    private var bookingSummaryBody: some View {
        let now = Date()
        let stornoLines = bookingSummaryStornoLines(now: now)

        return HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(booking.title ?? bookingTypeTitle(booking))
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    if isOverlapping {
                        Text(overlapCount > 0 ? "Überschneidung (+\(overlapCount))" : "Überschneidung")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }

                Text(bookingSummaryDateRangeText())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

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
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 2) {
                ProviderLogo(providerID: booking.provider)
                Text(bookingTypeTitle(booking))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(bookingPriceText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
            }
            .fixedSize(horizontal: true, vertical: false)
        }
    }

    private var bookingDetailsBody: some View {
        let now = Date()
        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 12) {
                SelectableBookingTextView(
                    attributedString: bookingAttributedDisplayText(now: now),
                    copyText: bookingFullCopyText(now: now)
                )
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .trailing, spacing: 2) {
                    ProviderLogo(providerID: booking.provider)
                    Text(bookingTypeTitle(booking))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(bookingPriceText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                }
                .fixedSize(horizontal: true, vertical: false)
            }

        }
    }
}

private struct GapRow: View {
    let gap: ComputedGap
    let displayMode: TimelineRowDisplayMode
    let displayTitle: String
    let effectiveKind: GapKind
    let priceText: String?
    let onEdit: () -> Void
    var onSelect: (() -> Void)? = nil

    @Environment(\.providerRegistry) private var providerRegistry

    private var hotelTimeZone: TimeZone {
        let offsetSeconds = (gap.fromBooking.hotelOffsetSeconds
            ?? gap.toBooking.hotelOffsetSeconds)
        if let offsetSeconds { return TimeZone(secondsFromGMT: offsetSeconds) ?? .current }
        return .current
    }

    private var linkSuggestions: (links: [DeepLinkSuggestion], issues: [DeepLinkIssue]) {
        let context = GapContext(
            gapStart: gap.gapStart,
            gapEnd: gap.gapEnd,
            kind: effectiveKind,
            fromLocationFrom: gap.fromBooking.locationFrom,
            fromLocationTo: gap.fromBooking.locationTo,
            toLocationFrom: gap.toBooking.locationFrom,
            toLocationTo: gap.toBooking.locationTo
        )
        if let builder = providerRegistry?.deepLinkBuilder(id: .check24) {
            return builder.suggestions(for: context)
        }
        return ([], [])
    }

    var body: some View {
        Group {
            if displayMode == .summary {
                gapSummaryBody
            } else {
                gapDetailsBody
            }
        }
        .padding(.vertical, 4)
    }

    private var gapSummaryBody: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(displayTitle)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                Text("\(formatOrtszeit(gap.gapStart, dateFormat: "d.M.", timeZone: hotelTimeZone)) – \(formatOrtszeit(gap.gapEnd, dateFormat: "d.M.", timeZone: hotelTimeZone))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Text(effectiveKind.rawValue)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var gapDetailsBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(displayTitle)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    Text("\(formatOrtszeit(gap.gapStart, dateFormat: "d.M.", timeZone: hotelTimeZone)) – \(formatOrtszeit(gap.gapEnd, dateFormat: "d.M.", timeZone: hotelTimeZone))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Button("Bearbeiten") {
                    onEdit()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            Text("Typ: \(effectiveKind.rawValue)")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let priceText {
                Text("Preis: \(priceText)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                ForEach(Array(linkSuggestions.links.enumerated()), id: \.offset) { _, suggestion in
                    if let url = suggestion.url {
                        let isHotel = suggestion.title.localizedCaseInsensitiveContains("hotel")
                        if !isHotel || effectiveKind == .lodging || effectiveKind == .both {
                            Button(suggestion.title) {
                                NSWorkspace.shared.open(url)
                            }
                        }
                    }
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            if !linkSuggestions.issues.isEmpty {
                Text(linkSuggestions.issues.compactMap(\.errorDescription).joined(separator: " "))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

