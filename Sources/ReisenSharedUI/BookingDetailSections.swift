import SwiftUI
import ReisenDomain
import ReisenData

/// Ein Tarif-Feld (Label/Wert) für Detail-UIs.
public struct BookingRateField: Identifiable, Equatable, Sendable {
    public var id: String { label }
    public let label: String
    public let value: String
    public let copyKind: FieldCopyKind

    public init(label: String, value: String, copyKind: FieldCopyKind = .standard) {
        self.label = label
        self.value = value
        self.copyKind = copyKind
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

/// SSOT für Status, Orte und Start/Ende/Check-in/out.
public enum BookingScheduleFields {
    public static func make(booking: SDBooking) -> [BookingRateField] {
        var fields: [BookingRateField] = [
            BookingRateField(label: BookingDetailLabels.status, value: booking.status.displayLabel)
        ]
        if let code = booking.confirmationCode, !code.isEmpty {
            fields.append(
                BookingRateField(
                    label: BookingDetailLabels.confirmationNumber,
                    value: code,
                    copyKind: .identifier
                )
            )
        }
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

        if bookingType == .hotel {
            appendSchedulePair(
                to: &fields,
                startLabel: startLabel,
                endLabel: endLabel,
                startValue: HotelStayDate.format(
                    booking.startAt,
                    dateFormat: "d.M.yyyy",
                    legacyHotelOffsetSeconds: booking.hotelOffsetSeconds
                ),
                endValue: HotelStayDate.format(
                    booking.endAt,
                    dateFormat: "d.M.yyyy",
                    legacyHotelOffsetSeconds: booking.hotelOffsetSeconds
                )
            )
        } else if bookingType.usesFlightLikeSchedule {
            appendSchedulePair(
                to: &fields,
                startLabel: startLabel,
                endLabel: endLabel,
                startValue: Formatting.formatOrtszeit(
                    booking.startAt,
                    dateFormat: "d.M.yyyy HH:mm",
                    timeZone: booking.resolvedFlightDepartureTimeZone
                ),
                endValue: Formatting.formatOrtszeit(
                    booking.endAt,
                    dateFormat: "d.M.yyyy HH:mm",
                    timeZone: booking.resolvedFlightArrivalTimeZone
                )
            )
        } else {
            appendSchedulePair(
                to: &fields,
                startLabel: startLabel,
                endLabel: endLabel,
                startValue: Formatting.formatOrtszeit(
                    booking.startAt,
                    dateFormat: activityDateFormat,
                    timeZone: booking.resolvedHotelTimeZone
                ),
                endValue: Formatting.formatOrtszeit(
                    booking.endAt,
                    dateFormat: activityDateFormat,
                    timeZone: booking.resolvedHotelTimeZone
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

    private static func appendSchedulePair(
        to fields: inout [BookingRateField],
        startLabel: String,
        endLabel: String,
        startValue: String,
        endValue: String
    ) {
        fields.append(BookingRateField(label: startLabel, value: startValue))
        fields.append(BookingRateField(label: endLabel, value: endValue))
    }
}

/// Zimmer-/Positions-Liste einer Buchungsrate (iOS + macOS).
public struct BookingRoomItemsView: View {
    let rate: SDBookingRateDetails
    let style: CopyableLabeledValueStyle

    public init(rate: SDBookingRateDetails, style: CopyableLabeledValueStyle = .inspector) {
        self.rate = rate
        self.style = style
    }

    private var sortedItems: [SDBookingRoomItem] {
        rate.resolvedRoomItems.sorted(by: { ($0.sortIndex ?? 0) < ($1.sortIndex ?? 0) })
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(sortedItems) { item in
                BookingRoomItemRow(item: item, rateCurrency: rate.totalPriceCurrency, style: style)
            }
        }
    }
}

/// Eine Zimmerposition — als eigene List-Zeile oder Inspector-Block.
public struct BookingRoomItemRow: View {
    let item: SDBookingRoomItem
    let rateCurrency: String?
    let style: CopyableLabeledValueStyle

    public init(item: SDBookingRoomItem, rateCurrency: String?, style: CopyableLabeledValueStyle) {
        self.item = item
        self.rateCurrency = rateCurrency
        self.style = style
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let category = item.category, !category.isEmpty {
                if style == .list {
                    Text(category)
                        .font(.body.weight(.medium))
                        .copyableValue(category)
                } else {
                    CopyableFieldValue(
                        value: category,
                        kind: .standard,
                        textStyle: .caption,
                        lineLimit: 2
                    )
                }
            }
            if let code = item.confirmationCode, !code.isEmpty {
                CopyableLabeledValue(
                    label: BookingDetailLabels.confirmationNumber,
                    value: code,
                    kind: .identifier,
                    style: style,
                    valueTextStyle: style.detailValueTextStyle
                )
            }
            if let guest = item.guestSummary, !guest.isEmpty {
                CopyableLabeledValue(
                    label: BookingDetailLabels.guests,
                    value: guest,
                    kind: .standard,
                    style: style,
                    valueTextStyle: style.detailValueTextStyle
                )
            }
            if let amount = item.priceAmount {
                let currency = item.priceCurrency ?? rateCurrency
                let price = Formatting.formatCurrencyAmount(amount, currencyCode: currency)
                CopyableLabeledValue(
                    label: BookingDetailLabels.unitPrice,
                    value: price,
                    kind: .standard,
                    style: style,
                    valueTextStyle: style.detailValueTextStyle
                )
            }
        }
        .bookingDetailRowPadding(style)
    }
}

/// Stornofristen einer Buchung (Hotel-TZ, einheitliches Datumsformat).
public struct BookingCancellationDeadlinesView: View {
    let booking: SDBooking
    let hotelTimeZone: TimeZone
    let style: CopyableLabeledValueStyle

    public init(
        booking: SDBooking,
        hotelTimeZone: TimeZone? = nil,
        style: CopyableLabeledValueStyle = .inspector
    ) {
        self.booking = booking
        self.hotelTimeZone = hotelTimeZone ?? booking.resolvedHotelTimeZone
        self.style = style
    }

    private var sortedDeadlines: [SDCancellationDeadline] {
        booking.resolvedCancellationDeadlines.sorted(by: { $0.deadlineAt < $1.deadlineAt })
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(sortedDeadlines, id: \.id) { deadline in
                BookingCancellationDeadlineRow(
                    deadline: deadline,
                    feeCurrency: booking.rateDetails?.totalPriceCurrency,
                    hotelTimeZone: hotelTimeZone,
                    style: style
                )
            }
        }
    }
}

/// Eine Stornofrist — als eigene List-Zeile oder Inspector-Block.
public struct BookingCancellationDeadlineRow: View {
    let deadline: SDCancellationDeadline
    let feeCurrency: String?
    let hotelTimeZone: TimeZone
    let style: CopyableLabeledValueStyle

    public init(
        deadline: SDCancellationDeadline,
        feeCurrency: String?,
        hotelTimeZone: TimeZone,
        style: CopyableLabeledValueStyle
    ) {
        self.deadline = deadline
        self.feeCurrency = feeCurrency
        self.hotelTimeZone = hotelTimeZone
        self.style = style
    }

    private var deadlineText: String {
        let tz = deadline.hotelOffsetSeconds.flatMap { TimeZone(secondsFromGMT: $0) }
            ?? hotelTimeZone
        return Formatting.formatOrtszeit(
            deadline.deadlineAt,
            dateFormat: "d.M.yyyy HH:mm",
            timeZone: tz
        )
    }

    private var freePaid: String {
        deadline.isFreeCancellation
            ? BookingDetailLabels.cancellationFree
            : BookingDetailLabels.cancellationPaid
    }

    private var feeText: String? {
        guard let fee = deadline.cancellationFeeAmount else { return nil }
        return Formatting.formatCurrencyAmount(fee, currencyCode: feeCurrency)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if style == .list {
                listBody
            } else {
                inspectorBody
            }
        }
        .bookingDetailRowPadding(style)
    }

    @ViewBuilder
    private var listBody: some View {
        CopyableLabeledValue(
            label: L10n.string(.editorCancellationUntil),
            value: deadlineText,
            kind: .standard,
            style: .list
        )
        CopyableLabeledValue(
            label: BookingDetailLabels.cancellationCost,
            value: freePaid,
            kind: .standard,
            style: .list
        )
        if let feeText {
            CopyableLabeledValue(
                label: L10n.string(.editorFee),
                value: feeText,
                kind: .standard,
                style: .list
            )
        }
        if deadline.isStrict {
            Text(BookingDetailLabels.strictDeadline)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        if let policy = deadline.policyText, !policy.isEmpty {
            CopyableLabeledValue(
                label: L10n.string(.editorPolicyText),
                value: policy,
                kind: .standard,
                style: .list,
                valueLineLimit: 6
            )
        }
    }

    @ViewBuilder
    private var inspectorBody: some View {
        CopyableFieldValue(
            value: deadlineText,
            kind: .standard,
            textStyle: .caption,
            lineLimit: 2
        )

        HStack(spacing: 8) {
            CopyableFieldValue(
                value: freePaid,
                kind: .standard,
                textStyle: .caption2,
                foregroundStyle: deadline.isFreeCancellation ? Color.green : Color.secondary
            )

            if let feeText {
                CopyableFieldValue(
                    value: feeText,
                    kind: .standard,
                    textStyle: .caption2,
                    foregroundStyle: .secondary
                )
            }

            if deadline.isStrict {
                Text(BookingDetailLabels.strictDeadline)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }

        if let policy = deadline.policyText, !policy.isEmpty {
            CopyableFieldValue(
                value: policy,
                kind: .standard,
                textStyle: .caption2,
                foregroundStyle: .secondary,
                lineLimit: 6
            )
        }
    }
}

public struct BookingGuestHintsView: View {
    let booking: SDBooking
    let style: CopyableLabeledValueStyle

    public init(booking: SDBooking, style: CopyableLabeledValueStyle = .inspector) {
        self.booking = booking
        self.style = style
    }

    private var sortedHints: [SDBookingGuestHint] {
        booking.resolvedGuestHints.sorted(by: { $0.title < $1.title })
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(sortedHints, id: \.id) { hint in
                BookingGuestHintRow(hint: hint, style: style)
            }
        }
    }
}

/// Ein Gast-Hinweis — als eigene List-Zeile oder Inspector-Block.
public struct BookingGuestHintRow: View {
    let hint: SDBookingGuestHint
    let style: CopyableLabeledValueStyle

    public init(hint: SDBookingGuestHint, style: CopyableLabeledValueStyle) {
        self.hint = hint
        self.style = style
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            CopyableLabeledValue(
                label: L10n.string(.editorHintTitle),
                value: hint.title,
                kind: .standard,
                style: style,
                valueTextStyle: style.titleValueTextStyle
            )
            if !hint.detail.isEmpty {
                CopyableLabeledValue(
                    label: L10n.string(.editorHintDetail),
                    value: hint.detail,
                    kind: .standard,
                    style: style,
                    valueTextStyle: style.detailValueTextStyle,
                    valueLineLimit: 8
                )
            }
        }
        .bookingDetailRowPadding(style)
    }
}

private extension View {
    func bookingDetailRowPadding(_ style: CopyableLabeledValueStyle) -> some View {
        padding(.vertical, style == .inspector ? 4 : 0)
    }
}
