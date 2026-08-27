import SwiftUI
import ReisenDomain
import ReisenData

/// Ein Tarif-Feld (Label/Wert) für Detail-UIs.
public struct BookingRateField: Identifiable, Equatable, Sendable {
    public var id: String { label }
    public let label: String
    public let value: String

    public init(label: String, value: String) {
        self.label = label
        self.value = value
    }
}

/// SSOT für Preis-/Tarif-Zeilen (ohne Zimmerpositionen).
public enum BookingRateFields {
    public static func make(rate: SDBookingRateDetails, booking: SDBooking) -> [BookingRateField] {
        var fields: [BookingRateField] = []
        let bookingType = booking.bookingType

        if let amount = rate.totalPriceAmount {
            fields.append(
                BookingRateField(
                    label: BookingDetailLabels.price,
                    value: Formatting.formatCurrencyAmount(amount, currencyCode: rate.totalPriceCurrency)
                )
            )
        }
        if let currency = rate.totalPriceCurrency, !currency.isEmpty {
            fields.append(BookingRateField(label: BookingDetailLabels.currency, value: currency))
        }
        if rate.resolvedRoomItems.isEmpty,
           let room = rate.roomCategory,
           !room.isEmpty,
           let roomLabel = bookingType.roomCategoryLabel {
            fields.append(BookingRateField(label: roomLabel, value: room))
        }
        if let breakfast = rate.includedBreakfast {
            fields.append(
                BookingRateField(
                    label: BookingDetailLabels.breakfastIncluded,
                    value: BookingDetailLabels.yesNo(breakfast)
                )
            )
        }
        if let guests = rate.guestCount {
            fields.append(BookingRateField(label: BookingDetailLabels.guests, value: "\(guests)"))
        }
        if let rooms = rate.roomCount, let roomCountLabel = bookingType.roomCountLabel {
            fields.append(BookingRateField(label: roomCountLabel, value: "\(rooms)"))
        }
        if let airline = rate.airline, !airline.isEmpty {
            fields.append(BookingRateField(label: BookingDetailLabels.airline, value: airline))
        }

        let names = booking.passengerDisplayNames
        if !names.isEmpty {
            fields.append(BookingRateField(label: BookingDetailLabels.passengers, value: names.joined(separator: ", ")))
        } else if let passengers = rate.passengerCount {
            fields.append(BookingRateField(label: BookingDetailLabels.passengers, value: "\(passengers)"))
        }

        if let baggage = rate.baggageInfoRaw, !baggage.isEmpty {
            fields.append(BookingRateField(label: BookingDetailLabels.baggage, value: baggage))
        }
        if let rawBoardType = rate.boardTypeRaw,
           !rawBoardType.isEmpty,
           let boardType = BookingBoardType(rawValue: rawBoardType),
           let boardLabel = boardType.displayLabelIfKnown {
            fields.append(BookingRateField(label: BookingDetailLabels.boardType, value: boardLabel))
        }
        if let parsed = rate.lastParsedAt {
            fields.append(
                BookingRateField(
                    label: BookingDetailLabels.rateLastParsed,
                    value: parsed.formatted(date: .abbreviated, time: .shortened)
                )
            )
        }

        return fields
    }
}

/// Inline-Darstellung „Label: Wert“ (iOS-Listen).
public struct BookingRateFieldsView: View {
    let fields: [BookingRateField]

    public init(rate: SDBookingRateDetails, booking: SDBooking) {
        self.fields = BookingRateFields.make(rate: rate, booking: booking)
    }

    public init(fields: [BookingRateField]) {
        self.fields = fields
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(fields) { field in
                Text("\(field.label): \(field.value)")
                    .foregroundStyle(.secondary)
            }
        }
        .textSelection(.enabled)
    }
}

/// SSOT für Status, Orte und Start/Ende/Check-in/out.
public enum BookingScheduleFields {
    public static func make(booking: SDBooking) -> [BookingRateField] {
        var fields: [BookingRateField] = [
            BookingRateField(label: BookingDetailLabels.status, value: booking.status.displayLabel)
        ]
        let bookingType = booking.bookingType

        if bookingType.showsLocationFrom,
           let from = booking.locationFrom,
           !from.isEmpty {
            fields.append(BookingRateField(label: bookingType.locationFromLabel, value: from))
        }
        if let to = booking.locationTo, !to.isEmpty {
            fields.append(BookingRateField(label: bookingType.locationToLabel, value: to))
        }
        if bookingType.showsLocationFrom,
           let fromAddress = booking.locationFromAddress,
           !fromAddress.isEmpty,
           let fromAddressLabel = bookingType.locationFromAddressLabel {
            fields.append(BookingRateField(label: fromAddressLabel, value: fromAddress))
        }
        if let toAddress = booking.locationToAddress,
           !toAddress.isEmpty,
           let toAddressLabel = bookingType.locationToAddressLabel {
            fields.append(BookingRateField(label: toAddressLabel, value: toAddress))
        }
        if let operatorName = booking.operatorName, !operatorName.isEmpty {
            fields.append(BookingRateField(label: bookingType.operatorNameLabel, value: operatorName))
        }
        if booking.isAllDay == true {
            fields.append(
                BookingRateField(label: BookingDetailLabels.allDay, value: BookingDetailLabels.yesNo(true))
            )
        }

        let activityDateFormat = booking.isAllDay == true ? "d.M.yyyy" : "d.M.yyyy HH:mm"
        let startLabel = bookingType.scheduleStartLabel
        let endLabel = bookingType.scheduleEndLabel

        switch booking.bookingType {
        case .hotel:
            fields.append(
                BookingRateField(
                    label: startLabel,
                    value: HotelStayDate.format(
                        booking.startAt,
                        dateFormat: "d.M.yyyy",
                        legacyHotelOffsetSeconds: booking.hotelOffsetSeconds
                    )
                )
            )
            fields.append(
                BookingRateField(
                    label: endLabel,
                    value: HotelStayDate.format(
                        booking.endAt,
                        dateFormat: "d.M.yyyy",
                        legacyHotelOffsetSeconds: booking.hotelOffsetSeconds
                    )
                )
            )
        case .flight, .ferry:
            fields.append(
                BookingRateField(
                    label: startLabel,
                    value: Formatting.formatOrtszeit(
                        booking.startAt,
                        dateFormat: "d.M.yyyy HH:mm",
                        timeZone: booking.resolvedFlightDepartureTimeZone
                    )
                )
            )
            fields.append(
                BookingRateField(
                    label: endLabel,
                    value: Formatting.formatOrtszeit(
                        booking.endAt,
                        dateFormat: "d.M.yyyy HH:mm",
                        timeZone: booking.resolvedFlightArrivalTimeZone
                    )
                )
            )
        case .activity, .carRental, .other:
            fields.append(
                BookingRateField(
                    label: startLabel,
                    value: Formatting.formatOrtszeit(
                        booking.startAt,
                        dateFormat: activityDateFormat,
                        timeZone: booking.resolvedHotelTimeZone
                    )
                )
            )
            fields.append(
                BookingRateField(
                    label: endLabel,
                    value: Formatting.formatOrtszeit(
                        booking.endAt,
                        dateFormat: activityDateFormat,
                        timeZone: booking.resolvedHotelTimeZone
                    )
                )
            )
        }

        if let checkIn = booking.hotelCheckInMinutes {
            fields.append(
                BookingRateField(label: BookingDetailLabels.checkIn, value: Formatting.minutesToHHmm(checkIn))
            )
        }
        if let checkOut = booking.hotelCheckOutMinutes {
            fields.append(
                BookingRateField(label: BookingDetailLabels.checkOut, value: Formatting.minutesToHHmm(checkOut))
            )
        }

        return fields
    }
}

public struct BookingScheduleFieldsView: View {
    let fields: [BookingRateField]

    public init(booking: SDBooking) {
        self.fields = BookingScheduleFields.make(booking: booking)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(fields) { field in
                Text("\(field.label): \(field.value)")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// Zimmer-/Positions-Liste einer Buchungsrate (iOS + macOS).
public struct BookingRoomItemsView: View {
    let rate: SDBookingRateDetails

    public init(rate: SDBookingRateDetails) {
        self.rate = rate
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(rate.resolvedRoomItems.sorted(by: { ($0.sortIndex ?? 0) < ($1.sortIndex ?? 0) })) { item in
                VStack(alignment: .leading, spacing: 4) {
                    if let category = item.category, !category.isEmpty {
                        Text(category)
                            .font(.caption.weight(.medium))
                    }
                    if let code = item.confirmationCode, !code.isEmpty {
                        Text("\(BookingDetailLabels.confirmationNumber): \(code)")
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
                        Text("\(BookingDetailLabels.unitPrice): \(Formatting.formatCurrencyAmount(amount, currencyCode: currency))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}

/// Stornofristen einer Buchung (Hotel-TZ, einheitliches Datumsformat).
public struct BookingCancellationDeadlinesView: View {
    let booking: SDBooking
    let hotelTimeZone: TimeZone

    public init(booking: SDBooking, hotelTimeZone: TimeZone? = nil) {
        self.booking = booking
        self.hotelTimeZone = hotelTimeZone ?? booking.resolvedHotelTimeZone
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(
                booking.resolvedCancellationDeadlines.sorted(by: { $0.deadlineAt < $1.deadlineAt }),
                id: \.id
            ) { deadline in
                let tz = deadline.hotelOffsetSeconds.flatMap { TimeZone(secondsFromGMT: $0) }
                    ?? hotelTimeZone
                VStack(alignment: .leading, spacing: 6) {
                    Text(
                        Formatting.formatOrtszeit(
                            deadline.deadlineAt,
                            dateFormat: "d.M.yyyy HH:mm",
                            timeZone: tz
                        )
                    )
                    .font(.caption.weight(.medium))

                    HStack(spacing: 8) {
                        Text(deadline.isFreeCancellation ? BookingDetailLabels.cancellationFree : BookingDetailLabels.cancellationPaid)
                            .font(.caption2)
                            .foregroundStyle(deadline.isFreeCancellation ? .green : .secondary)

                        if let fee = deadline.cancellationFeeAmount {
                            Text(
                                Formatting.formatCurrencyAmount(
                                    fee,
                                    currencyCode: booking.rateDetails?.totalPriceCurrency
                                )
                            )
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        }

                        if deadline.isStrict {
                            Text(BookingDetailLabels.strictDeadline)
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
                .padding(.vertical, 4)
            }
        }
    }
}

public struct BookingGuestHintsView: View {
    let booking: SDBooking

    public init(booking: SDBooking) {
        self.booking = booking
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(booking.resolvedGuestHints.sorted(by: { $0.title < $1.title }), id: \.id) { hint in
                VStack(alignment: .leading, spacing: 4) {
                    Text(hint.title)
                        .font(.caption.weight(.medium))
                    if !hint.detail.isEmpty {
                        Text(hint.detail)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}
