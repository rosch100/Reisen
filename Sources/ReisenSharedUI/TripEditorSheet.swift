import SwiftUI
import SwiftData
import ReisenDomain
import ReisenData

public enum TripEditorMode {
    case create
    case edit
}

/// Plattformeinheitlicher Trip-Editor (macOS + iOS).
public struct TripEditorSheet: View {
    private enum FocusField: Hashable {
        case title
    }

    let mode: TripEditorMode
    let trip: SDTrip?
    let onSaved: ((SDTrip) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var title: String
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var errorMessage: String?
    @State private var pendingPeriodExpand: TripPeriodExpandOnAssign.Proposal?
    @State private var showPeriodExpandConfirm = false
    @FocusState private var focusedField: FocusField?

    private let seedBookingIDs: Set<UUID>?
    private let focusTitleOnAppear: Bool

    public init(
        mode: TripEditorMode,
        trip: SDTrip? = nil,
        seed: TripCreateSeed? = nil,
        onSaved: ((SDTrip) -> Void)? = nil
    ) {
        self.mode = mode
        self.trip = trip
        self.onSaved = onSaved
        self.seedBookingIDs = seed?.bookingIDs

        let now = Date()
        let defaultStart = Calendar.current.startOfDay(for: now)
        let defaultEnd = Calendar.current.date(byAdding: .day, value: 3, to: defaultStart) ?? defaultStart

        if let trip {
            _title = State(initialValue: trip.title)
            _startDate = State(initialValue: trip.startDate)
            _endDate = State(initialValue: trip.endDate)
            focusTitleOnAppear = false
        } else if let seed {
            _title = State(initialValue: seed.title ?? "")
            _startDate = State(initialValue: seed.startDate)
            _endDate = State(initialValue: seed.endDate)
            focusTitleOnAppear = seed.title?.isEmpty ?? true
        } else {
            _title = State(initialValue: "")
            _startDate = State(initialValue: defaultStart)
            _endDate = State(initialValue: defaultEnd)
            focusTitleOnAppear = true
        }
    }

    private var isValid: Bool {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        return endDate >= startDate
    }

    public var body: some View {
        VStack(spacing: 0) {
            Text(
                mode == .create
                    ? L10n.string(.actionNewTrip)
                    : "\(L10n.string(.tripTripSection)) \(L10n.string(.commonEdit))"
            )
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 14)

            Form {
                Section(L10n.string(.tripTripSection)) {
                    TextField(L10n.string(.tripNameField), text: $title)
                        .focused($focusedField, equals: .title)
                    DatePicker(L10n.string(.tripStartDate), selection: $startDate, displayedComponents: .date)
                    DatePicker(L10n.string(.tripEndDate), selection: $endDate, displayedComponents: .date)
                }

                if mode == .create {
                    TripEditorAssignmentPreviewSection(
                        startDate: startDate,
                        endDate: endDate,
                        seedBookingIDs: seedBookingIDs
                    )
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .textSelection(.enabled)
                    }
                }
            }
            .formStyle(.grouped)
            .padding(.horizontal, 8)

            Divider()

            HStack {
                Button(L10n.string(.commonCancel)) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button(L10n.string(.commonSave)) { save() }
                    .disabled(!isValid)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(16)
        }
#if os(macOS)
        .frame(minWidth: 480, idealWidth: 480, minHeight: 320, maxHeight: 440)
        .presentationSizing(.fitted)
#endif
        .onAppear {
            if focusTitleOnAppear {
                focusedField = .title
            }
        }
        .alert(
            TripPeriodExpandPrompt.title,
            isPresented: $showPeriodExpandConfirm
        ) {
            Button(TripPeriodExpandPrompt.confirmAction) {
                if let pendingPeriodExpand {
                    startDate = pendingPeriodExpand.start
                    endDate = pendingPeriodExpand.end
                }
                persist(assignSeedOutsideWindow: true)
            }
            Button(TripPeriodExpandPrompt.declineAction, role: .cancel) {
                persist(assignSeedOutsideWindow: false)
            }
        } message: {
            if let pendingPeriodExpand {
                Text(TripPeriodExpandPrompt.message(for: pendingPeriodExpand))
            }
        }
    }

    private func save() {
        errorMessage = nil
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, endDate >= startDate else { return }

        if mode == .create, let seedBookingIDs, !seedBookingIDs.isEmpty {
            do {
                let bookingRepo = SwiftDataBookingRepository(modelContext: modelContext)
                let bookings = try bookingRepo.fetchAll().filter { seedBookingIDs.contains($0.id) }
                let ranges = bookings.map { (start: $0.startAt, end: $0.endAt) }
                if let proposal = TripPeriodExpandOnAssign.proposalIfNeeded(
                    bookings: ranges,
                    tripStart: startDate,
                    tripEnd: endDate
                ) {
                    pendingPeriodExpand = proposal
                    showPeriodExpandConfirm = true
                    return
                }
            } catch {
                errorMessage = error.localizedDescription
                return
            }
        }

        persist(assignSeedOutsideWindow: true)
    }

    /// - Parameter assignSeedOutsideWindow: `true` after confirm (dates already expanded) or when no expand needed; `false` on decline (only in-window seeds).
    private func persist(assignSeedOutsideWindow: Bool) {
        errorMessage = nil
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, endDate >= startDate else { return }

        do {
            let savedTrip: SDTrip
            switch mode {
            case .create:
                let newTrip = SDTrip(
                    title: trimmed,
                    startDate: startDate,
                    endDate: endDate,
                    destination: nil,
                    notes: nil
                )
                modelContext.insert(newTrip)
                savedTrip = newTrip
            case .edit:
                guard let trip else { return }
                trip.title = trimmed
                trip.startDate = startDate
                trip.endDate = endDate
                savedTrip = trip
            }

            let bookingRepo = SwiftDataBookingRepository(modelContext: modelContext)
            let tripRepo = SwiftDataTripRepository(modelContext: modelContext)
            let domainTrip = DomainMapper.trip(from: savedTrip)
            let bookings = try bookingRepo.fetchAll()
            let restrictingTo: Set<UUID>?
            if mode == .create, let seedBookingIDs {
                if assignSeedOutsideWindow {
                    restrictingTo = seedBookingIDs
                } else {
                    restrictingTo = Set(
                        bookings.compactMap { booking -> UUID? in
                            guard seedBookingIDs.contains(booking.id) else { return nil }
                            guard TripBookingDateWindow.contains(
                                bookingStart: booking.startAt,
                                bookingEnd: booking.endAt,
                                tripStart: startDate,
                                tripEnd: endDate
                            ) else { return nil }
                            return booking.id
                        }
                    )
                }
            } else {
                restrictingTo = nil
            }
            let ids = TripBookingAssignment().bookingIDsToAssign(
                bookings: bookings,
                trip: domainTrip,
                restrictingTo: restrictingTo
            )
            for bookingID in ids {
                try tripRepo.assignBooking(bookingID: bookingID, toTripID: savedTrip.id)
            }
            try tripRepo.save()

            pendingPeriodExpand = nil
            showPeriodExpandConfirm = false
            onSaved?(savedTrip)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

/// Live preview of bookings that `save()` will assign (create flow).
private struct TripEditorAssignmentPreviewSection: View {
    private struct RefreshKey: Equatable {
        let startDate: Date
        let endDate: Date
        let openBookingRevision: Int
    }

    let startDate: Date
    let endDate: Date
    let seedBookingIDs: Set<UUID>?

    @Query(sort: \SDBooking.startAt, order: .forward) private var allBookings: [SDBooking]
    @State private var assignableCount = 0

    var body: some View {
        Group {
            if assignableCount > 0 {
                Section {
                    Text(previewText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .onAppear {
            refreshAssignableCount()
        }
        .onChange(of: refreshKey) { _, _ in
            refreshAssignableCount()
        }
    }

    private var previewText: String {
        if seedBookingIDs != nil {
            return L10n.format(.tripAssignCountSelected, assignableCount)
        }
        return L10n.format(.tripAssignCountInWindow, assignableCount)
    }

    private var refreshKey: RefreshKey {
        RefreshKey(
            startDate: startDate,
            endDate: endDate,
            openBookingRevision: openBookingRevision
        )
    }

    private var openBookingRevision: Int {
        var hasher = Hasher()
        for booking in allBookings where OpenBookingMatching.isOpenUnassigned(booking) {
            hasher.combine(booking.id)
            hasher.combine(booking.startAt)
            hasher.combine(booking.endAt)
        }
        return hasher.finalize()
    }

    private func refreshAssignableCount() {
        let bookings = allBookings.map(DomainMapper.booking(from:))
        let draftTrip = Trip(title: "", startDate: startDate, endDate: endDate)
        assignableCount = TripBookingAssignment().bookingIDsToAssign(
            bookings: bookings,
            trip: draftTrip,
            restrictingTo: seedBookingIDs
        ).count
    }
}
