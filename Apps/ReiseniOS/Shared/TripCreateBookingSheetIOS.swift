import SwiftUI
import SwiftData
import ReisenSharedUI
import ReisenDomain
import ReisenData
import ReisenDiagnostics

/// iOS-Sheet: manuelle Buchung in einer Reise anlegen (Parität zu macOS `actionAddBooking`).
struct TripCreateBookingSheetIOS: View {
    let trip: SDTrip
    @Binding var draft: BookingEditorDraft?
    @Binding var isPresented: Bool

    @Environment(\.modelContext) private var modelContext
    @State private var pendingPeriodExpand: TripPeriodExpandOnAssign.Proposal?
    @State private var showPeriodExpandConfirm = false
    @State private var persistErrorMessage: String?

    var body: some View {
        Group {
            if let draftBinding {
                BookingEditorForm(
                    title: L10n.string(.actionAddBooking),
                    showsSyncOverwriteHint: false,
                    draft: draftBinding,
                    providerReadOnly: true,
                    onCancel: dismissEditor,
                    onSave: {
                        guard let draft else { return }
                        try saveCreate(draft)
                    }
                )
                .reisenSheetDetents()
            }
        }
        .alert(
            TripPeriodExpandPrompt.title,
            isPresented: $showPeriodExpandConfirm
        ) {
            Button(TripPeriodExpandPrompt.confirmAction) {
                confirmPeriodExpandAndCreate()
            }
            Button(TripPeriodExpandPrompt.declineAction, role: .cancel) {
                declinePeriodExpandAndCreateOpen()
            }
        } message: {
            if let pendingPeriodExpand {
                Text(TripPeriodExpandPrompt.message(for: pendingPeriodExpand))
            }
        }
        .persistFailureAlert(message: $persistErrorMessage)
    }

    private var draftBinding: Binding<BookingEditorDraft>? {
        guard draft != nil else { return nil }
        return Binding(
            get: {
                guard let draft else {
                    preconditionFailure("create booking sheet binding without draft")
                }
                return draft
            },
            set: { draft = $0 }
        )
    }

    private func saveCreate(_ draft: BookingEditorDraft) throws {
        switch TripCreateBookingAssignment.plan(
            bookingType: draft.bookingType,
            draftStartAt: draft.startAt,
            draftEndAt: draft.endAt,
            tripStart: trip.startDate,
            tripEnd: trip.endDate
        ) {
        case .askExpand(let proposal):
            pendingPeriodExpand = proposal
            showPeriodExpandConfirm = true
        case .assignToTrip:
            try createAssigned(to: trip)
            dismissEditor()
        }
    }

    private func confirmPeriodExpandAndCreate() {
        guard let proposal = pendingPeriodExpand else { return }
        trip.startDate = proposal.start
        trip.endDate = proposal.end
        do {
            try createAssigned(to: trip)
            dismissEditor()
        } catch {
            Self.recordPersistFailure(operation: "booking_create_period_expand", error: error)
            persistErrorMessage = error.localizedDescription
        }
    }

    private func declinePeriodExpandAndCreateOpen() {
        do {
            try createAssigned(to: nil)
            dismissEditor()
        } catch {
            Self.recordPersistFailure(operation: "booking_create_open", error: error)
            persistErrorMessage = error.localizedDescription
        }
    }

    private func createAssigned(to trip: SDTrip?) throws {
        guard let draft else { return }
        _ = try BookingEditorDraft.createBooking(
            from: draft,
            trip: trip,
            in: modelContext
        )
    }

    private func dismissEditor() {
        showPeriodExpandConfirm = false
        pendingPeriodExpand = nil
        isPresented = false
        draft = nil
    }

    static func start(draft: inout BookingEditorDraft?, isPresented: inout Bool, trip: SDTrip) {
        draft = BookingEditorDraft.createDefault(tripStartDate: trip.startDate)
        isPresented = true
        recordCreateDraftSelected()
    }

    private static func recordCreateDraftSelected() {
        Task {
            await DiagnosticLogger.shared.record(
                DiagnosticEvent(
                    context: DiagnosticContext(
                        runID: UUID(),
                        providerID: .manual,
                        operation: "booking_create"
                    ),
                    component: "TripCreateBookingSheetIOS",
                    phase: "booking_create",
                    event: "create_draft_selected",
                    result: .started,
                    reason: "ios_trip_detail_add_booking",
                    visibility: .publicDiagnostic
                )
            )
        }
    }

    private static func recordPersistFailure(operation: String, error: Error) {
        Task {
            await DiagnosticLogger.shared.record(
                DiagnosticEvent(
                    context: DiagnosticContext(
                        runID: UUID(),
                        providerID: .manual,
                        operation: operation
                    ),
                    component: "TripCreateBookingSheetIOS",
                    phase: "persist",
                    event: operation,
                    result: .failed,
                    reason: String(describing: type(of: error)),
                    visibility: .publicDiagnostic
                )
            )
        }
    }
}
