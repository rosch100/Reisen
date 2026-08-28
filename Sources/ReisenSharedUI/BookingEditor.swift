import SwiftUI
import SwiftData
import ReisenDomain
import ReisenData

// MARK: - Session

/// Anlegen/Bearbeiten läuft in der Detailspalte (Inspector), nicht als Modal-Sheet.
///
/// `prefilledDraft` bringt einen fertigen Entwurf mit (Paste-Import). Ist er gesetzt, baut der
/// Inspector den Entwurf **nicht** aus `createDefault`/`fromExisting` neu.
public enum BookingEditorSession: Equatable, Sendable {
    case create(prefillStart: Date?, prefillEnd: Date?, prefilledDraft: BookingEditorDraft? = nil)
    case edit(bookingID: UUID, prefilledDraft: BookingEditorDraft? = nil)
}

// MARK: - Draft Models

public struct CancellationDeadlineDraft: Identifiable, Equatable, Sendable {
    public var id: UUID = UUID()
    public var deadlineAt: Date
    public var policyText: String
    public var isStrict: Bool
    public var isFreeCancellation: Bool
    public var hotelOffsetSecondsText: String
    public var cancellationFeeAmountText: String

    public init(
        id: UUID = UUID(),
        deadlineAt: Date,
        policyText: String = "",
        isStrict: Bool = true,
        isFreeCancellation: Bool = true,
        hotelOffsetSecondsText: String = "",
        cancellationFeeAmountText: String = ""
    ) {
        self.id = id
        self.deadlineAt = deadlineAt
        self.policyText = policyText
        self.isStrict = isStrict
        self.isFreeCancellation = isFreeCancellation
        self.hotelOffsetSecondsText = hotelOffsetSecondsText
        self.cancellationFeeAmountText = cancellationFeeAmountText
    }
}

public enum BookingIncludedBreakfastState: String, CaseIterable, Identifiable, Sendable {
    case unknown
    case yes
    case no

    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .unknown: return L10n.string(.commonUnknown)
        case .yes: return L10n.string(.commonYes)
        case .no: return L10n.string(.commonNo)
        }
    }

    public func toBool() -> Bool? {
        switch self {
        case .unknown: return nil
        case .yes: return true
        case .no: return false
        }
    }

    public static func fromBool(_ value: Bool?) -> Self {
        switch value {
        case true: return .yes
        case false: return .no
        default: return .unknown
        }
    }
}

public struct BookingEditorDraft: Equatable, Sendable {
    public var bookingID: UUID?
    public var provider: ProviderID
    public var bookingType: BookingType
    public var status: BookingStatus
    public var title: String
    public var confirmationCode: String
    public var externalUrl: String
    public var startAt: Date
    public var endAt: Date
    public var locationFrom: String
    public var locationTo: String
    public var locationFromAddress: String
    public var locationToAddress: String
    public var hotelOffsetSecondsText: String
    public var flightDepartureOffsetSecondsText: String
    public var flightArrivalOffsetSecondsText: String
    public var hotelCheckInMinutesText: String
    public var hotelCheckOutMinutesText: String
    public var totalPriceAmountText: String
    public var totalPriceCurrency: String
    public var roomCategory: String
    public var operatorName: String
    public var boardType: BookingBoardType
    public var includedBreakfastState: BookingIncludedBreakfastState
    public var guestCountText: String
    public var roomCountText: String
    public var airline: String
    public var passengerCountText: String
    public var baggageInfoRaw: String
    public var lastParsedAt: Date?
    public var cancellationDeadlines: [CancellationDeadlineDraft]
    public var passengers: [BookingPassenger]
    public var guestHints: [BookingGuestHint]

    public static func createDefault(
        tripStartDate: Date,
        prefillStart: Date? = nil,
        prefillEnd: Date? = nil,
        now: Date = Date()
    ) -> BookingEditorDraft {
        let start = prefillStart ?? max(now, tripStartDate)
        let computedEnd = Calendar.current.date(byAdding: .day, value: 3, to: start) ?? start
        let end = max(prefillEnd ?? computedEnd, start)
        return BookingEditorDraft(
            bookingID: nil,
            provider: .manual,
            bookingType: .hotel,
            status: .confirmed,
            title: "",
            confirmationCode: "",
            externalUrl: "",
            startAt: start,
            endAt: end,
            locationFrom: "",
            locationTo: "",
            locationFromAddress: "",
            locationToAddress: "",
            hotelOffsetSecondsText: "",
            flightDepartureOffsetSecondsText: "",
            flightArrivalOffsetSecondsText: "",
            hotelCheckInMinutesText: "60",
            hotelCheckOutMinutesText: "120",
            totalPriceAmountText: "",
            totalPriceCurrency: "EUR",
            roomCategory: "",
            operatorName: "",
            boardType: .unknown,
            includedBreakfastState: .unknown,
            guestCountText: "",
            roomCountText: "",
            airline: "",
            passengerCountText: "",
            baggageInfoRaw: "",
            lastParsedAt: nil,
            cancellationDeadlines: [],
            passengers: [],
            guestHints: []
        )
    }

    public static func fromExisting(_ booking: SDBooking) -> BookingEditorDraft {
        fromDomain(DomainMapper.booking(from: booking))
    }

    /// Editor-Felder aus einer Domain-Buchung — SSOT für `fromExisting` und Paste-Import-Prefill.
    public static func fromDomain(_ booking: Booking) -> BookingEditorDraft {
        BookingEditorDraft(
            bookingID: booking.id,
            provider: booking.provider,
            bookingType: booking.bookingType,
            status: booking.status,
            title: booking.title ?? "",
            confirmationCode: booking.confirmationCode ?? "",
            externalUrl: booking.externalUrl ?? "",
            startAt: booking.startAt,
            endAt: booking.endAt,
            locationFrom: booking.locationFrom ?? "",
            locationTo: booking.locationTo ?? "",
            locationFromAddress: booking.locationFromAddress ?? "",
            locationToAddress: booking.locationToAddress ?? "",
            hotelOffsetSecondsText: booking.hotelOffsetSeconds.map { String($0) } ?? "",
            flightDepartureOffsetSecondsText: booking.flightDepartureOffsetSeconds.map { String($0) } ?? "",
            flightArrivalOffsetSecondsText: booking.flightArrivalOffsetSeconds.map { String($0) } ?? "",
            hotelCheckInMinutesText: booking.hotelCheckInMinutes.map { String($0) } ?? "",
            hotelCheckOutMinutesText: booking.hotelCheckOutMinutes.map { String($0) } ?? "",
            totalPriceAmountText: booking.rateDetails?.totalPriceAmount.map { String($0) } ?? "",
            totalPriceCurrency: booking.rateDetails?.totalPriceCurrency ?? "EUR",
            roomCategory: booking.rateDetails?.roomCategory ?? "",
            operatorName: booking.operatorName ?? "",
            boardType: booking.rateDetails?.boardType ?? .unknown,
            includedBreakfastState: BookingIncludedBreakfastState.fromBool(booking.rateDetails?.includedBreakfast),
            guestCountText: booking.rateDetails?.guestCount.map { String($0) } ?? "",
            roomCountText: booking.rateDetails?.roomCount.map { String($0) } ?? "",
            airline: booking.rateDetails?.airline ?? "",
            passengerCountText: booking.rateDetails?.passengerCount.map { String($0) } ?? "",
            baggageInfoRaw: booking.rateDetails?.baggageInfoRaw ?? "",
            lastParsedAt: booking.rateDetails?.lastParsedAt,
            cancellationDeadlines: booking.cancellationDeadlines
                .map { deadline in
                    CancellationDeadlineDraft(
                        id: deadline.id,
                        deadlineAt: deadline.deadlineAt,
                        policyText: deadline.policyText ?? "",
                        isStrict: deadline.isStrict,
                        isFreeCancellation: deadline.isFreeCancellation,
                        hotelOffsetSecondsText: deadline.hotelOffsetSeconds.map { String($0) } ?? "",
                        cancellationFeeAmountText: deadline.cancellationFeeAmount.map { String($0) } ?? ""
                    )
                }
                .sorted { $0.deadlineAt < $1.deadlineAt },
            passengers: booking.passengers,
            guestHints: booking.guestHints
        )
    }

    public enum ValidationError: LocalizedError, Sendable {
        case emptyTitle
        case endBeforeStart
        case invalidNumber(field: String)
        case invalidUrl

        public var errorDescription: String? {
            switch self {
            case .emptyTitle: return L10n.string(.editorValidationEmptyTitle)
            case .endBeforeStart: return L10n.string(.editorValidationEndBeforeStart)
            case .invalidNumber(let field): return L10n.format(.editorValidationInvalidNumber, field)
            case .invalidUrl: return L10n.string(.editorValidationInvalidUrl)
            }
        }
    }

    public static func parseIntOrNil(_ text: String) -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return Int(trimmed)
    }

    public static func parseDoubleOrNil(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "de_DE_POSIX")
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 6
        return formatter.number(from: trimmed)?.doubleValue
    }

    public static func normalizeOptionalString(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return trimmed
    }

    public func validate() throws {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { throw ValidationError.emptyTitle }
        guard endAt >= startAt else { throw ValidationError.endBeforeStart }

        if !externalUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            guard URL(string: externalUrl) != nil else { throw ValidationError.invalidUrl }
        }

        try ensureOptionalInt(L10n.string(.editorFieldHotelOffset), hotelOffsetSecondsText)
        try ensureOptionalInt(L10n.string(.editorFieldDepartureOffset), flightDepartureOffsetSecondsText)
        try ensureOptionalInt(L10n.string(.editorFieldArrivalOffset), flightArrivalOffsetSecondsText)
        try ensureOptionalInt(L10n.string(.editorFieldCheckInMinutes), hotelCheckInMinutesText)
        try ensureOptionalInt(L10n.string(.editorFieldCheckOutMinutes), hotelCheckOutMinutesText)
        try ensureOptionalDouble(L10n.string(.editorFieldPrice), totalPriceAmountText)
        try ensureOptionalInt(L10n.string(.editorFieldGuests), guestCountText)
        try ensureOptionalInt(L10n.string(.editorFieldRooms), roomCountText)
        try ensureOptionalInt(L10n.string(.editorFieldPassengers), passengerCountText)

        for (index, deadline) in cancellationDeadlines.enumerated() {
            try ensureOptionalInt(
                L10n.format(.editorFieldCancellationOffset, index + 1),
                deadline.hotelOffsetSecondsText
            )
            try ensureOptionalDouble(
                L10n.format(.editorFieldCancellationFee, index + 1),
                deadline.cancellationFeeAmountText
            )
        }
    }

    private func ensureOptionalInt(_ name: String, _ text: String) throws {
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return }
        guard Self.parseIntOrNil(text) != nil else {
            throw ValidationError.invalidNumber(field: name)
        }
    }

    private func ensureOptionalDouble(_ name: String, _ text: String) throws {
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return }
        guard Self.parseDoubleOrNil(text) != nil else {
            throw ValidationError.invalidNumber(field: name)
        }
    }

    /// Neue manuelle Buchung anlegen und persistieren.
    ///
    /// - Parameter trip: `nil` legt die Buchung ohne Reise an (Offen); es wird keine Ersatzreise gesucht.
    @discardableResult
    public static func createBooking(
        from draft: BookingEditorDraft,
        trip: SDTrip?,
        in modelContext: ModelContext
    ) throws -> UUID {
        var working = draft
        working.provider = .manual
        if working.externalUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            working.externalUrl = BookingExternalURL.makeManual()
        }
        try working.validate()

        let booking = SDBooking(
            providerRaw: ProviderID.manual.rawValue,
            bookingTypeRaw: working.bookingType.rawValue,
            title: working.title.trimmingCharacters(in: .whitespacesAndNewlines),
            confirmationCode: normalizeOptionalString(working.confirmationCode),
            externalUrl: normalizeOptionalString(working.externalUrl),
            startAt: working.startAt,
            endAt: working.endAt,
            locationFrom: normalizeOptionalString(working.locationFrom),
            locationTo: normalizeOptionalString(working.locationTo),
            statusRaw: working.status.rawValue,
            hotelOffsetSeconds: parseIntOrNil(working.hotelOffsetSecondsText),
            flightDepartureOffsetSeconds: parseIntOrNil(working.flightDepartureOffsetSecondsText),
            flightArrivalOffsetSeconds: parseIntOrNil(working.flightArrivalOffsetSecondsText),
            hotelCheckInMinutes: parseIntOrNil(working.hotelCheckInMinutesText),
            hotelCheckOutMinutes: parseIntOrNil(working.hotelCheckOutMinutesText)
        )
        if let trip {
            booking.trip = trip
        }
        modelContext.insert(booking)
        try working.apply(to: booking, in: modelContext)
        return booking.id
    }

    public func apply(to booking: SDBooking, in modelContext: ModelContext) throws {
        try validate()

        booking.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        booking.confirmationCode = Self.normalizeOptionalString(confirmationCode)
        booking.externalUrl = Self.normalizeOptionalString(externalUrl)
        booking.locationFrom = Self.normalizeOptionalString(locationFrom)
        booking.locationTo = Self.normalizeOptionalString(locationTo)
        booking.locationFromAddress = Self.normalizeOptionalString(locationFromAddress)
        booking.locationToAddress = Self.normalizeOptionalString(locationToAddress)
        // Sichtbarkeit (`showsOperatorNameField`) ist keine Persistenzregel.
        if bookingType.persistsOperatorName {
            booking.operatorName = Self.normalizeOptionalString(operatorName)
        } else {
            booking.operatorName = nil
        }
        if bookingType == .hotel {
            booking.startAt = HotelStayDate.dateOnly(fromLocalPickerDate: startAt)
            booking.endAt = HotelStayDate.dateOnly(fromLocalPickerDate: endAt)
        } else {
            booking.startAt = startAt
            booking.endAt = endAt
        }
        booking.bookingTypeRaw = bookingType.rawValue
        booking.statusRaw = status.rawValue
        booking.hotelOffsetSeconds = Self.parseIntOrNil(hotelOffsetSecondsText)
        booking.flightDepartureOffsetSeconds = Self.parseIntOrNil(flightDepartureOffsetSecondsText)
        booking.flightArrivalOffsetSeconds = Self.parseIntOrNil(flightArrivalOffsetSecondsText)
        booking.hotelCheckInMinutes = Self.parseIntOrNil(hotelCheckInMinutesText)
        booking.hotelCheckOutMinutes = Self.parseIntOrNil(hotelCheckOutMinutesText)

        // Structured passengers/baggage for flights.
        // Replace-Strategy: delete all existing SwiftData child models and recreate from the edited draft.
        for existing in booking.resolvedPassengers {
            modelContext.delete(existing)
        }
        if bookingType == .flight {
            booking.passengers = passengers.enumerated().map { index, pax in
                let updatedNumber = index + 1
                let sdPassenger = SDBookingPassenger(
                    booking: booking,
                    passengerNumber: updatedNumber,
                    travellerTypeRaw: pax.travellerType.rawValue,
                    title: pax.title.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0.trimmingCharacters(in: .whitespacesAndNewlines) } ?? nil,
                    givenName: pax.givenName.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0.trimmingCharacters(in: .whitespacesAndNewlines) } ?? nil,
                    familyName: pax.familyName.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0.trimmingCharacters(in: .whitespacesAndNewlines) } ?? nil,
                    secondFamilyName: pax.secondFamilyName.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0.trimmingCharacters(in: .whitespacesAndNewlines) } ?? nil,
                    birthDate: pax.birthDate
                )
                sdPassenger.baggageAllowances = pax.baggageAllowances.map { allowance in
                    SDBaggageAllowance(
                        passenger: sdPassenger,
                        baggageTypeRaw: allowance.type.rawValue,
                        pieceCount: allowance.pieceCount,
                        weightKg: allowance.weightKg,
                        sectionID: allowance.sectionID,
                        airlineCode: allowance.airlineCode,
                        fromLabel: allowance.fromLabel.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0.trimmingCharacters(in: .whitespacesAndNewlines) } ?? nil,
                        toLabel: allowance.toLabel.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0.trimmingCharacters(in: .whitespacesAndNewlines) } ?? nil
                    )
                }
                return sdPassenger
            }
        } else {
            booking.passengers = []
        }

        let hasAnyRateField =
            !totalPriceAmountText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !roomCategory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || boardType != .unknown
            || includedBreakfastState != .unknown
            || !guestCountText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !roomCountText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !airline.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !passengerCountText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !baggageInfoRaw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || (bookingType == .flight && !passengers.isEmpty)

        if hasAnyRateField {
            let rate = booking.rateDetails ?? SDBookingRateDetails(booking: booking)
            booking.rateDetails = rate
            rate.totalPriceAmount = Self.parseDoubleOrNil(totalPriceAmountText)
            rate.totalPriceCurrency = Self.normalizeOptionalString(totalPriceCurrency) ?? "EUR"
            rate.roomCategory = Self.normalizeOptionalString(roomCategory)
            rate.boardTypeRaw = boardType == .unknown ? nil : boardType.rawValue
            rate.includedBreakfast = includedBreakfastState.toBool()
            rate.guestCount = Self.parseIntOrNil(guestCountText)
            rate.roomCount = Self.parseIntOrNil(roomCountText)
            rate.airline = Self.normalizeOptionalString(airline)
            if bookingType == .flight, !passengers.isEmpty {
                rate.passengerCount = passengers.count
                rate.baggageInfoRaw = Self.structuredBaggageInfoRaw(passengers: passengers)
            } else {
                rate.passengerCount = Self.parseIntOrNil(passengerCountText)
                rate.baggageInfoRaw = Self.normalizeOptionalString(baggageInfoRaw)
            }
            rate.lastParsedAt = rate.lastParsedAt ?? lastParsedAt
        } else if let existing = booking.rateDetails {
            modelContext.delete(existing)
            booking.rateDetails = nil
        }

        for existing in booking.resolvedCancellationDeadlines {
            modelContext.delete(existing)
        }
        booking.cancellationDeadlines = cancellationDeadlines
            .sorted { $0.deadlineAt < $1.deadlineAt }
            .map { draft in
                SDCancellationDeadline(
                    deadlineAt: draft.deadlineAt,
                    policyText: Self.normalizeOptionalString(draft.policyText),
                    isStrict: draft.isStrict,
                    isFreeCancellation: draft.isFreeCancellation,
                    hotelOffsetSeconds: Self.parseIntOrNil(draft.hotelOffsetSecondsText),
                    cancellationFeeAmount: Self.parseDoubleOrNil(draft.cancellationFeeAmountText),
                    booking: booking
                )
            }

        let persistedHints = guestHints.compactMap {
            BookingGuestHint.manualPersistable(from: $0, bookingID: booking.id)
        }
        SwiftDataBookingGuestHintUpsert.upsert(persistedHints, on: booking, in: modelContext)

        try modelContext.save()
    }
}

private struct BookingPassengerEditorRow: View {
    @Binding var pax: BookingPassenger
    let removePassenger: (UUID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Menu {
                Button(L10n.travellerTypeDisplay(.adult)) { pax.travellerType = .adult }
                Button(L10n.travellerTypeDisplay(.child)) { pax.travellerType = .child }
                Button(L10n.travellerTypeDisplay(.infant)) { pax.travellerType = .infant }
                Button(L10n.travellerTypeDisplay(.unknown)) { pax.travellerType = .unknown }
            } label: {
                Text(L10n.travellerTypeDisplay(pax.travellerType))
            }

            HStack {
                let titleBinding = Binding<String>(
                    get: { pax.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "" },
                    set: { newValue in
                        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                        pax.title = trimmed.isEmpty ? nil : trimmed
                    }
                )
                let givenNameBinding = Binding<String>(
                    get: { pax.givenName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "" },
                    set: { newValue in
                        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                        pax.givenName = trimmed.isEmpty ? nil : trimmed
                    }
                )

                TextField(L10n.string(.editorTitle), text: titleBinding)
                TextField(L10n.string(.editorGivenName), text: givenNameBinding)
            }

            TextField(
                L10n.string(.editorFamilyName),
                text: Binding<String>(
                    get: { pax.familyName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "" },
                    set: { newValue in
                        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                        pax.familyName = trimmed.isEmpty ? nil : trimmed
                    }
                )
            )

            HStack {
                DatePicker(
                    L10n.string(.editorBirthDate),
                    selection: Binding<Date>(
                        get: { pax.birthDate ?? Date() },
                        set: { pax.birthDate = $0 }
                    ),
                    displayedComponents: .date
                )
                Button(L10n.string(.editorClearBirthDate), role: .destructive) { pax.birthDate = nil }
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.string(.bookingDetailBaggage))

                ForEach(pax.baggageAllowances.indices, id: \.self) { idx in
                    HStack {
                        Menu {
                            Button(L10n.baggageTypeDisplay(.checkedBag)) { pax.baggageAllowances[idx].type = .checkedBag }
                            Button(L10n.baggageTypeDisplay(.cabinBag)) { pax.baggageAllowances[idx].type = .cabinBag }
                            Button(L10n.baggageTypeDisplay(.personalItem)) { pax.baggageAllowances[idx].type = .personalItem }
                            Button(L10n.baggageTypeDisplay(.unknown)) { pax.baggageAllowances[idx].type = .unknown }
                        } label: {
                            Text(L10n.baggageTypeDisplay(pax.baggageAllowances[idx].type))
                        }

                        TextField(L10n.string(.editorPieces), value: Binding<Int?>(
                            get: { pax.baggageAllowances[idx].pieceCount },
                            set: { pax.baggageAllowances[idx].pieceCount = $0 }
                        ), format: .number)
                        TextField(L10n.string(.editorWeightKg), value: Binding<Double?>(
                            get: { pax.baggageAllowances[idx].weightKg },
                            set: { pax.baggageAllowances[idx].weightKg = $0 }
                        ), format: .number)

                        Button(L10n.string(.editorRemoveBaggage), role: .destructive) {
                            pax.baggageAllowances.remove(at: idx)
                        }
                    }
                }

                Button {
                    pax.baggageAllowances.append(
                        BaggageAllowance(
                            type: .unknown,
                            pieceCount: nil,
                            weightKg: nil
                        )
                    )
                } label: {
                    Label(L10n.string(.editorAddBaggage), systemImage: "plus")
                }
            }

            Button(L10n.string(.editorRemovePassenger), role: .destructive) {
                removePassenger(pax.id)
            }
            .buttonStyle(.plain)
        }
    }
}

private extension BookingEditorDraft {
    static func structuredBaggageInfoRaw(passengers: [BookingPassenger]) -> String {
        BaggageInfoFormatter.baggageInfoRaw(passengers: passengers)
    }
}

// MARK: - Inspector Form (HIG)

/// Scrollbares Formular mit sticky Fußleiste - für die rechte Detailspalte (kein Modal).
public struct BookingEditorForm: View {
    let title: String
    let showsSyncOverwriteHint: Bool
    @Binding var draft: BookingEditorDraft
    let providerReadOnly: Bool
    var onCancel: () -> Void
    var onSave: () throws -> Void

    @State private var errorMessage: String?

    private var computedEndAtMin: Date { draft.startAt }

    private var scheduleDateComponents: DatePicker.Components {
        draft.bookingType == .hotel ? [.date] : [.date, .hourAndMinute]
    }

    public init(
        title: String,
        showsSyncOverwriteHint: Bool,
        draft: Binding<BookingEditorDraft>,
        providerReadOnly: Bool,
        onCancel: @escaping () -> Void,
        onSave: @escaping () throws -> Void
    ) {
        self.title = title
        self.showsSyncOverwriteHint = showsSyncOverwriteHint
        self._draft = draft
        self.providerReadOnly = providerReadOnly
        self.onCancel = onCancel
        self.onSave = onSave
    }

    public var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                if showsSyncOverwriteHint {
                    Text(L10n.string(.editorSyncOverwriteWarning))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 8)

            Divider()

            Form {
                Section(L10n.string(.editorGeneral)) {
                    if providerReadOnly {
                        LabeledContent(L10n.string(.editorProvider), value: draft.provider.rawValue.capitalized)
                    }
                    TextField(L10n.string(.editorTitle), text: $draft.title)
                    Picker(L10n.string(.editorType), selection: $draft.bookingType) {
                        ForEach(BookingType.allCases) { type in
                            BookingTypeLabel(type).tag(type)
                        }
                    }
                    Picker(L10n.string(.bookingDetailStatus), selection: $draft.status) {
                        ForEach(BookingStatus.allCases) { status in
                            Text(localizedBookingStatus(status)).tag(status)
                        }
                    }
                    TextField(L10n.string(.editorConfirmationCode), text: $draft.confirmationCode)
                    TextField(L10n.string(.editorUrlOptional), text: $draft.externalUrl)
                    DatePicker(
                        draft.bookingType.scheduleStartLabel,
                        selection: $draft.startAt,
                        displayedComponents: scheduleDateComponents
                    )
                    DatePicker(
                        draft.bookingType.scheduleEndLabel,
                        selection: $draft.endAt,
                        in: computedEndAtMin...,
                        displayedComponents: scheduleDateComponents
                    )
                    if draft.bookingType.showsLocationFrom {
                        TextField(draft.bookingType.locationFromLabel, text: $draft.locationFrom)
                    }
                    TextField(draft.bookingType.locationToLabel, text: $draft.locationTo)
                    if let fromAddressLabel = draft.bookingType.locationFromAddressLabel {
                        TextField(L10n.optionalFieldLabel(fromAddressLabel), text: $draft.locationFromAddress)
                    }
                    if let toAddressLabel = draft.bookingType.locationToAddressLabel {
                        TextField(L10n.optionalFieldLabel(toAddressLabel), text: $draft.locationToAddress)
                    }
                    if draft.bookingType.showsOperatorNameField {
                        TextField(draft.bookingType.operatorNameLabel, text: $draft.operatorName)
                    }
                }

                if draft.bookingType == .hotel {
                    Section(L10n.string(.editorHotel)) {
                        TextField(L10n.string(.editorHotelOffset), text: $draft.hotelOffsetSecondsText)
                        TextField(L10n.string(.editorCheckInMinutes), text: $draft.hotelCheckInMinutesText)
                        TextField(L10n.string(.editorCheckOutMinutes), text: $draft.hotelCheckOutMinutesText)
                    }
                } else if draft.bookingType == .flight {
                    Section(L10n.string(.editorFlight)) {
                        TextField(L10n.string(.editorDepartureOffset), text: $draft.flightDepartureOffsetSecondsText)
                        TextField(L10n.string(.editorArrivalOffset), text: $draft.flightArrivalOffsetSecondsText)
                    }
                }

                Section(BookingDetailLabels.rateSection) {
                    TextField(L10n.string(.bookingDetailPrice), text: $draft.totalPriceAmountText)
                    TextField(L10n.string(.bookingDetailCurrency), text: $draft.totalPriceCurrency)
                    if let roomCategoryLabel = draft.bookingType.roomCategoryLabel {
                        TextField(roomCategoryLabel, text: $draft.roomCategory)
                    }
                    if draft.bookingType == .hotel {
                        Menu {
                            ForEach(BookingBoardType.allCases) { bt in
                                Button(localizedBoardType(bt)) { draft.boardType = bt }
                            }
                        } label: {
                            Text(localizedBoardType(draft.boardType))
                        }

                        Menu {
                            ForEach(BookingIncludedBreakfastState.allCases) { s in
                                Button(s.label) { draft.includedBreakfastState = s }
                            }
                        } label: {
                            Text(draft.includedBreakfastState.label)
                        }
                        TextField(L10n.string(.bookingDetailGuests), text: $draft.guestCountText)
                        TextField(L10n.string(.editorFieldRooms), text: $draft.roomCountText)
                    }
                    if draft.bookingType == .flight {
                        if !draft.passengers.isEmpty {
                            Section(L10n.string(.bookingDetailPassengers)) {
                                let removePassengerAction: (UUID) -> Void = { id in
                                    draft.passengers.removeAll { $0.id == id }
                                }
                                ForEach($draft.passengers) { $pax in
                                    BookingPassengerEditorRow(
                                        pax: $pax,
                                        removePassenger: removePassengerAction
                                    )
                                    .padding(.vertical, 6)
                                }

                                Button {
                                    draft.passengers.append(
                                        BookingPassenger(
                                            passengerNumber: (draft.passengers.count + 1),
                                            travellerType: .adult,
                                            title: nil,
                                            givenName: nil,
                                            familyName: nil,
                                            birthDate: nil,
                                            baggageAllowances: []
                                        )
                                    )
                                } label: {
                                    Label(L10n.string(.editorAddPassenger), systemImage: "plus")
                                }
                            }
                        } else {
                            // Fallback für Provider, die (noch) keine strukturierten Passagiere liefern.
                            TextField(L10n.string(.editorFieldPassengers), text: $draft.passengerCountText)
                            TextField(L10n.string(.bookingDetailBaggage), text: $draft.baggageInfoRaw)
                        }
                        TextField(BookingDetailLabels.airline, text: $draft.airline)
                        if !draft.passengers.isEmpty {
                            Text(L10n.format(.editorPassengerCount, draft.passengers.count))
                            Text(L10n.string(.editorStructuredBaggageDerived))
                        }
                    }
                }

                Section(L10n.string(.editorCancellation)) {
                    ForEach($draft.cancellationDeadlines) { $deadline in
                        VStack(alignment: .leading, spacing: 8) {
                            DatePicker(
                                L10n.string(.editorCancellationUntil),
                                selection: $deadline.deadlineAt,
                                displayedComponents: [.date, .hourAndMinute]
                            )
                            Toggle(L10n.string(.editorFreeCancellation), isOn: $deadline.isFreeCancellation)
                            Toggle(BookingDetailLabels.strictDeadline, isOn: $deadline.isStrict)
                            TextField(L10n.string(.editorPolicyText), text: $deadline.policyText)
                            TextField(L10n.string(.editorOffsetSeconds), text: $deadline.hotelOffsetSecondsText)
                            TextField(L10n.string(.editorFee), text: $deadline.cancellationFeeAmountText)
                            Button(L10n.string(.editorRemoveEntry), role: .destructive) {
                                draft.cancellationDeadlines.removeAll { $0.id == deadline.id }
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    Button {
                        draft.cancellationDeadlines.append(
                            CancellationDeadlineDraft(deadlineAt: draft.startAt)
                        )
                    } label: {
                        Label(L10n.string(.editorAddCancellationDeadline), systemImage: "plus")
                    }
                }

                Section(GuestHintCategory.preTravelImportant.displayTitle) {
                    ForEach($draft.guestHints) { $hint in
                        VStack(alignment: .leading, spacing: 8) {
                            TextField(L10n.string(.editorTitle), text: $hint.title)
                            TextField(L10n.string(.editorHintDetail), text: $hint.detail, axis: .vertical)
                                .lineLimit(2...5)
                            Button(L10n.string(.editorRemoveEntry), role: .destructive) {
                                draft.guestHints.removeAll { $0.id == hint.id }
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    Button {
                        draft.guestHints.append(
                            BookingGuestHint(
                                category: .preTravelImportant,
                                title: "",
                                detail: "",
                                sourceKey: "manual:\(UUID().uuidString)",
                                providerRaw: ProviderID.manual.rawValue
                            )
                        )
                    } label: {
                        Label(L10n.string(.editorAddHint), systemImage: "plus")
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .formStyle(.grouped)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            HStack {
                Button(L10n.string(.commonCancel)) { onCancel() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button(L10n.string(.commonSave)) {
                    do {
                        try draft.validate()
                        try onSave()
                        errorMessage = nil
                    } catch {
                        errorMessage = (error as? LocalizedError)?.errorDescription
                            ?? String(describing: error)
                    }
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(.background)
    }

    private func localizedBookingStatus(_ status: BookingStatus) -> String {
        status.displayLabel
    }

    private func localizedBoardType(_ type: BookingBoardType) -> String {
        type.displayLabel
    }
}

