import Foundation
import ReisenDomain
import ReisenData

/// Ein Tarif-Feld (Label/Wert) für Detail-UIs.
public struct BookingRateField: Identifiable, Equatable, Sendable {
    public let id: String
    public let label: String
    public let value: String
    public let copyKind: FieldCopyKind

    public init(id: String, label: String, value: String, copyKind: FieldCopyKind = .standard) {
        self.id = id
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
                    id: "rate.price",
                    label: BookingDetailLabels.price,
                    value: Formatting.formatCurrencyAmount(amount, currencyCode: rate.totalPriceCurrency)
                )
            )
        }
        if rate.resolvedRoomItems.isEmpty,
           let room = rate.roomCategory,
           !room.isEmpty,
           let roomLabel = bookingType.roomCategoryLabel {
            fields.append(BookingRateField(id: "rate.roomCategory", label: roomLabel, value: room))
        }

        let knownBoardType: BookingBoardType? = {
            guard let raw = rate.boardTypeRaw, !raw.isEmpty,
                  let boardType = BookingBoardType(rawValue: raw),
                  boardType != .unknown else { return nil }
            return boardType
        }()

        if knownBoardType == nil, let breakfast = rate.includedBreakfast {
            fields.append(
                BookingRateField(
                    id: "rate.breakfast",
                    label: BookingDetailLabels.breakfastIncluded,
                    value: BookingDetailLabels.yesNo(breakfast)
                )
            )
        }
        if let guests = rate.guestCount {
            fields.append(
                BookingRateField(id: "rate.guests", label: BookingDetailLabels.guests, value: "\(guests)")
            )
        }
        if let rooms = rate.roomCount, let roomCountLabel = bookingType.roomCountLabel {
            fields.append(BookingRateField(id: "rate.roomCount", label: roomCountLabel, value: "\(rooms)"))
        }
        if let airline = rate.airline, !airline.isEmpty {
            fields.append(
                BookingRateField(id: "rate.airline", label: BookingDetailLabels.airline, value: airline)
            )
        }

        let names = booking.passengerDisplayNames
        if !names.isEmpty {
            fields.append(
                BookingRateField(
                    id: "rate.passengers.names",
                    label: BookingDetailLabels.passengers,
                    value: names.joined(separator: ", ")
                )
            )
        } else if let passengers = rate.passengerCount {
            fields.append(
                BookingRateField(
                    id: "rate.passengers.count",
                    label: BookingDetailLabels.passengers,
                    value: "\(passengers)"
                )
            )
        }

        if let baggage = rate.baggageInfoRaw, !baggage.isEmpty {
            fields.append(
                BookingRateField(id: "rate.baggage", label: BookingDetailLabels.baggage, value: baggage)
            )
        }
        if let boardType = knownBoardType, let boardLabel = boardType.displayLabelIfKnown {
            fields.append(
                BookingRateField(id: "rate.boardType", label: BookingDetailLabels.boardType, value: boardLabel)
            )
        }

        return fields
    }
}
