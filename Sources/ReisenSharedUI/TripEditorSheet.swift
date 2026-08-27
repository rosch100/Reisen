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
    @FocusState private var focusedField: FocusField?

    private let showsAssignmentPreview: Bool
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
        self.showsAssignmentPreview = mode == .create && seed != nil

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

                if showsAssignmentPreview {
                    TripEditorAssignmentPreviewSection(
                        startDate: startDate,
                        endDate: endDate
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
    }

    private func save() {
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
            let ids = TripBookingAssignment().assignableBookingIDs(bookings: bookings, trip: domainTrip)
            for bookingID in ids {
                try tripRepo.assignBooking(bookingID: bookingID, toTripID: savedTrip.id)
            }
            try tripRepo.save()

            onSaved?(savedTrip)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

/// Live preview of assignable open bookings; `@Query` only when seeded create flow is active.
private struct TripEditorAssignmentPreviewSection: View {
    private struct RefreshKey: Equatable {
        let startDate: Date
        let endDate: Date
        let openBookingRevision: Int
    }

    let startDate: Date
    let endDate: Date

    @Query(sort: \SDBooking.startAt, order: .forward) private var allBookings: [SDBooking]
    @State private var assignableCount = 0

    var body: some View {
        Group {
            if assignableCount > 0 {
                Section {
                    Text(L10n.format(.tripAssignCountInWindow, assignableCount))
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
            hasher.combine(booking.trip?.id)
        }
        return hasher.finalize()
    }

    private func refreshAssignableCount() {
        let bookings = allBookings.map(DomainMapper.booking(from:))
        assignableCount = TripBookingAssignment().assignableCount(
            bookings: bookings,
            startDate: startDate,
            endDate: endDate
        )
    }
}
