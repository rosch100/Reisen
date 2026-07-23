import SwiftUI
import SwiftData
import ReisenDomain
import ReisenData

// MARK: - Session

/// Anlegen/Bearbeiten läuft in der Detailspalte (Inspector), nicht als Modal-Sheet.
public enum BookingEditorSession: Equatable, Sendable {
    case create(prefillStart: Date?, prefillEnd: Date?)
    case edit(bookingID: UUID)
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
        case .unknown: return "Unbekannt"
        case .yes: return "Ja"
        case .no: return "Nein"
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
            boardType: .unknown,
            includedBreakfastState: .unknown,
            guestCountText: "",
            roomCountText: "",
            airline: "",
            passengerCountText: "",
            baggageInfoRaw: "",
            lastParsedAt: nil,
            cancellationDeadlines: [],
            passengers: []
        )
    }

    public static func fromExisting(_ booking: SDBooking) -> BookingEditorDraft {
        BookingEditorDraft(
            bookingID: booking.id,
            provider: ProviderID(rawValue: booking.providerRaw),
            bookingType: BookingType(rawValue: booking.bookingTypeRaw) ?? .other,
            status: BookingStatus(rawValue: booking.statusRaw) ?? .unknown,
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
            boardType: BookingBoardType(rawValue: booking.rateDetails?.boardTypeRaw ?? "") ?? .unknown,
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
            passengers: booking.passengers.map(DomainMapper.passenger(from:))
        )
    }

    public enum ValidationError: LocalizedError, Sendable {
        case emptyTitle
        case endBeforeStart
        case invalidNumber(field: String)
        case invalidUrl

        public var errorDescription: String? {
            switch self {
            case .emptyTitle: return "Bitte einen Titel eingeben."
            case .endBeforeStart: return "Ende darf nicht vor Start liegen."
            case .invalidNumber(let field): return "Ungültiger Zahlenwert: \(field)."
            case .invalidUrl: return "Ungültige URL."
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

        try ensureOptionalInt("Hotel-Offset", hotelOffsetSecondsText)
        try ensureOptionalInt("Abflug-Offset", flightDepartureOffsetSecondsText)
        try ensureOptionalInt("Ankunft-Offset", flightArrivalOffsetSecondsText)
        try ensureOptionalInt("Check-in Minuten", hotelCheckInMinutesText)
        try ensureOptionalInt("Check-out Minuten", hotelCheckOutMinutesText)
        try ensureOptionalDouble("Preis", totalPriceAmountText)
        try ensureOptionalInt("Gäste", guestCountText)
        try ensureOptionalInt("Zimmer", roomCountText)
        try ensureOptionalInt("Passagiere", passengerCountText)

        for (index, deadline) in cancellationDeadlines.enumerated() {
            try ensureOptionalInt("Storno[\(index + 1)] Offset", deadline.hotelOffsetSecondsText)
            try ensureOptionalDouble("Storno[\(index + 1)] Gebühr", deadline.cancellationFeeAmountText)
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
    @discardableResult
    public static func createBooking(
        from draft: BookingEditorDraft,
        trip: SDTrip,
        in modelContext: ModelContext
    ) throws -> UUID {
        var working = draft
        working.provider = .manual
        if working.externalUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            working.externalUrl = "reisen://manual/\(UUID().uuidString)"
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
        booking.trip = trip
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
        for existing in booking.passengers {
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

        for existing in booking.cancellationDeadlines {
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

        try modelContext.save()
    }
}

private struct BookingPassengerEditorRow: View {
    @Binding var pax: BookingPassenger
    let removePassenger: (UUID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Menu {
                Button(localizedTravellerType(.adult)) { pax.travellerType = .adult }
                Button(localizedTravellerType(.child)) { pax.travellerType = .child }
                Button(localizedTravellerType(.infant)) { pax.travellerType = .infant }
                Button(localizedTravellerType(.unknown)) { pax.travellerType = .unknown }
            } label: {
                Text(localizedTravellerType(pax.travellerType))
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

                TextField(PassengerEditorText.titleField, text: titleBinding)
                TextField(PassengerEditorText.givenNameField, text: givenNameBinding)
            }

            TextField(
                PassengerEditorText.familyNameField,
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
                    PassengerEditorText.birthDateField,
                    selection: Binding<Date>(
                        get: { pax.birthDate ?? Date() },
                        set: { pax.birthDate = $0 }
                    ),
                    displayedComponents: .date
                )
                Button(PassengerEditorText.clearBirthDate, role: .destructive) { pax.birthDate = nil }
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text(PassengerEditorText.baggageSectionTitle)

                ForEach(pax.baggageAllowances.indices, id: \.self) { idx in
                    HStack {
                        Menu {
                            Button(localizedBaggageType(.checkedBag)) { pax.baggageAllowances[idx].type = .checkedBag }
                            Button(localizedBaggageType(.cabinBag)) { pax.baggageAllowances[idx].type = .cabinBag }
                            Button(localizedBaggageType(.personalItem)) { pax.baggageAllowances[idx].type = .personalItem }
                            Button(localizedBaggageType(.unknown)) { pax.baggageAllowances[idx].type = .unknown }
                        } label: {
                            Text(localizedBaggageType(pax.baggageAllowances[idx].type))
                        }

                        TextField(PassengerEditorText.piecesField, value: Binding<Int?>(
                            get: { pax.baggageAllowances[idx].pieceCount },
                            set: { pax.baggageAllowances[idx].pieceCount = $0 }
                        ), format: .number)
                        TextField(PassengerEditorText.weightKgField, value: Binding<Double?>(
                            get: { pax.baggageAllowances[idx].weightKg },
                            set: { pax.baggageAllowances[idx].weightKg = $0 }
                        ), format: .number)

                        Button(PassengerEditorText.removeBaggageAllowance, role: .destructive) {
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
                    Label(PassengerEditorText.addBaggageAllowance, systemImage: "plus")
                }
            }

            Button(PassengerEditorText.removePassenger, role: .destructive) {
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

private enum PassengerEditorText {
    static let titleField = "Titel"
    static let givenNameField = "Vorname"
    static let familyNameField = "Nachname"

    static let baggageSectionTitle = "Gepäck"

    static let birthDateField = "Geburtsdatum"
    static let clearBirthDate = "Datum löschen"

    static let piecesField = "Stück"
    static let weightKgField = "Gewicht (kg)"

    static let removeBaggageAllowance = "Entfernen"
    static let addBaggageAllowance = "Gepäck hinzufügen"

    static let removePassenger = "Passagier entfernen"

    static let passengerCountField = "Passagiere"
    static let baggageInfoRawField = "Gepäck"
    static let structuredBaggageDerivedText = "Gepäck wird aus den strukturierten Allowances abgeleitet."
}

private func localizedTravellerType(_ type: TravellerType) -> String {
    switch type {
    case .adult: return "Erwachsener"
    case .child: return "Kind"
    case .infant: return "Säugling"
    case .unknown: return "Unbekannt"
    }
}

private func localizedBaggageType(_ type: BaggageType) -> String {
    switch type {
    case .checkedBag: return "Aufgegebenes Gepäck"
    case .cabinBag: return "Handgepäck"
    case .personalItem: return "Persönlicher Gegenstand"
    case .unknown: return "Unbekannt"
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
                    Text("Änderungen können beim nächsten Sync überschrieben werden.")
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
                Section("Allgemein") {
                    if providerReadOnly {
                        LabeledContent("Provider", value: draft.provider.rawValue.capitalized)
                    }
                    TextField("Titel", text: $draft.title)
                    Picker("Typ", selection: $draft.bookingType) {
                        ForEach(BookingType.allCases) { type in
                            Text(localizedBookingType(type)).tag(type)
                        }
                    }
                    Picker("Status", selection: $draft.status) {
                        ForEach(BookingStatus.allCases) { status in
                            Text(localizedBookingStatus(status)).tag(status)
                        }
                    }
                    TextField("Bestätigungscode", text: $draft.confirmationCode)
                    TextField("URL (optional)", text: $draft.externalUrl)
                    DatePicker(
                        "Start",
                        selection: $draft.startAt,
                        displayedComponents: draft.bookingType == .hotel ? [.date] : [.date, .hourAndMinute]
                    )
                    DatePicker(
                        "Ende",
                        selection: $draft.endAt,
                        in: computedEndAtMin...,
                        displayedComponents: draft.bookingType == .hotel ? [.date] : [.date, .hourAndMinute]
                    )
                    TextField("Von", text: $draft.locationFrom)
                    TextField("Nach", text: $draft.locationTo)
                    TextField("Adresse von (optional)", text: $draft.locationFromAddress)
                    TextField("Adresse nach (optional)", text: $draft.locationToAddress)
                }

                if draft.bookingType == .hotel {
                    Section("Hotel") {
                        TextField("Hotel-Offset (s)", text: $draft.hotelOffsetSecondsText)
                        TextField("Check-in (Minuten)", text: $draft.hotelCheckInMinutesText)
                        TextField("Check-out (Minuten)", text: $draft.hotelCheckOutMinutesText)
                    }
                } else if draft.bookingType == .flight {
                    Section("Flug") {
                        TextField("Abflug-Offset (s)", text: $draft.flightDepartureOffsetSecondsText)
                        TextField("Ankunft-Offset (s)", text: $draft.flightArrivalOffsetSecondsText)
                    }
                }

                Section("Preis / Tarif") {
                    TextField("Preis", text: $draft.totalPriceAmountText)
                    TextField("Währung", text: $draft.totalPriceCurrency)
                    if draft.bookingType == .hotel {
                        TextField("Zimmerkategorie", text: $draft.roomCategory)
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
                        TextField("Gäste", text: $draft.guestCountText)
                        TextField("Zimmer", text: $draft.roomCountText)
                    }
                    if draft.bookingType == .flight {
                        if !draft.passengers.isEmpty {
                            Section("Passagiere") {
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
                                    Label("Passagier hinzufügen", systemImage: "plus")
                                }
                            }
                        } else {
                            // Fallback für Provider, die (noch) keine strukturierten Passagiere liefern.
                            TextField(PassengerEditorText.passengerCountField, text: $draft.passengerCountText)
                            TextField(PassengerEditorText.baggageInfoRawField, text: $draft.baggageInfoRaw)
                        }
                        TextField("Airline", text: $draft.airline)
                        if !draft.passengers.isEmpty {
                            Text("\(draft.passengers.count) Passagiere")
                            Text(PassengerEditorText.structuredBaggageDerivedText)
                        }
                    }
                }

                Section("Stornierung") {
                    ForEach($draft.cancellationDeadlines) { $deadline in
                        VStack(alignment: .leading, spacing: 8) {
                            DatePicker(
                                "Storno bis",
                                selection: $deadline.deadlineAt,
                                displayedComponents: [.date, .hourAndMinute]
                            )
                            Toggle("Kostenlos", isOn: $deadline.isFreeCancellation)
                            Toggle("Strikt", isOn: $deadline.isStrict)
                            TextField("Policy-Text", text: $deadline.policyText)
                            TextField("Offset (s)", text: $deadline.hotelOffsetSecondsText)
                            TextField("Gebühr", text: $deadline.cancellationFeeAmountText)
                            Button("Eintrag entfernen", role: .destructive) {
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
                        Label("Stornofrist hinzufügen", systemImage: "plus")
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
                Button("Abbrechen") { onCancel() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Sichern") {
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

    private func localizedBookingType(_ type: BookingType) -> String {
        switch type {
        case .flight: return "Flug"
        case .hotel: return "Hotel"
        case .ferry: return "Fähre"
        case .other: return "Sonstiges"
        }
    }

    private func localizedBookingStatus(_ status: BookingStatus) -> String {
        switch status {
        case .confirmed: return "Bestätigt"
        case .cancelled: return "Storniert"
        case .unknown: return "Unbekannt"
        }
    }

    private func localizedBoardType(_ type: BookingBoardType) -> String {
        switch type {
        case .roomOnly: return "Nur Zimmer"
        case .breakfastIncluded: return "Frühstück"
        case .halfBoard: return "Halbpension"
        case .fullBoard: return "Vollpension"
        case .unknown: return "Unbekannt"
        }
    }
}

