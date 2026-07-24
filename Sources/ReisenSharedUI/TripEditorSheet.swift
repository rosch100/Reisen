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
    let mode: TripEditorMode
    let trip: SDTrip?
    let onSaved: ((SDTrip) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var title: String
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var errorMessage: String?

    public init(
        mode: TripEditorMode,
        trip: SDTrip? = nil,
        onSaved: ((SDTrip) -> Void)? = nil
    ) {
        self.mode = mode
        self.trip = trip
        self.onSaved = onSaved

        let now = Date()
        let defaultStart = Calendar.current.startOfDay(for: now)
        let defaultEnd = Calendar.current.date(byAdding: .day, value: 3, to: defaultStart) ?? defaultStart

        if let trip {
            _title = State(initialValue: trip.title)
            _startDate = State(initialValue: trip.startDate)
            _endDate = State(initialValue: trip.endDate)
        } else {
            _title = State(initialValue: "")
            _startDate = State(initialValue: defaultStart)
            _endDate = State(initialValue: defaultEnd)
        }
    }

    private var isValid: Bool {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        return endDate >= startDate
    }

    public var body: some View {
        VStack(spacing: 0) {
            Text(mode == .create ? "Neue Reise" : "Reise bearbeiten")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 14)

            Form {
                Section("Reise") {
                    TextField("Name", text: $title)
                    DatePicker("Start", selection: $startDate, displayedComponents: .date)
                    DatePicker("Ende", selection: $endDate, displayedComponents: .date)
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
                Button("Abbrechen") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Sichern") { save() }
                    .disabled(!isValid)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(16)
        }
        .frame(width: 480, height: 320)
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

