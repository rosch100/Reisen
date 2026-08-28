import Foundation

/// Roh-Zeitfakten vor DateWindow-Interpretation.
public enum TemporalFact: Equatable, Sendable {
    case iso(String)
    case hotelDay(Date, offsetSeconds: Int?)
    case wallClockAsUTC(Date, offsetSeconds: Int)
    case instant(Date)

    /// Geparste `Date`s: Domain interpretiert nach `bookingType` (Hotel → Kalendertag-Fakt).
    /// ISO-Strings weiter als `.iso` übergeben. Extract wählt nicht zwischen Instant und HotelDay.
    public static func pair(
        bookingType: BookingType,
        start: Date,
        end: Date,
        hotelOffsetSeconds: Int? = nil
    ) -> (start: TemporalFact, end: TemporalFact) {
        switch bookingType {
        case .hotel:
            return (
                .hotelDay(start, offsetSeconds: hotelOffsetSeconds),
                .hotelDay(end, offsetSeconds: hotelOffsetSeconds)
            )
        case .flight, .ferry, .activity, .carRental, .other:
            return (.instant(start), .instant(end))
        }
    }
}

public struct BookingDateWindow: Equatable, Sendable {
    public var startAt: Date
    public var endAt: Date
    public var hotelOffsetSeconds: Int?
    public var flightDepartureOffsetSeconds: Int?
    public var flightArrivalOffsetSeconds: Int?

    public init(
        startAt: Date,
        endAt: Date,
        hotelOffsetSeconds: Int? = nil,
        flightDepartureOffsetSeconds: Int? = nil,
        flightArrivalOffsetSeconds: Int? = nil
    ) {
        self.startAt = startAt
        self.endAt = endAt
        self.hotelOffsetSeconds = hotelOffsetSeconds
        self.flightDepartureOffsetSeconds = flightDepartureOffsetSeconds
        self.flightArrivalOffsetSeconds = flightArrivalOffsetSeconds
    }

    public static func resolve(
        type: BookingType,
        start: TemporalFact,
        end: TemporalFact
    ) -> BookingDateWindow? {
        switch (start, end) {
        case let (.instant(startAt), .instant(endAt)):
            return resolveParsed(
                type: type,
                startAt: startAt,
                endAt: endAt,
                startOffset: nil,
                endOffset: nil
            )

        case let (.hotelDay(startAt, startOffset), .hotelDay(endAt, endOffset)):
            return resolveParsed(
                type: type,
                startAt: startAt,
                endAt: endAt,
                startOffset: startOffset,
                endOffset: endOffset
            )

        case let (.wallClockAsUTC(startAt, startOffset), .wallClockAsUTC(endAt, endOffset)):
            return resolveParsed(
                type: type,
                startAt: startAt,
                endAt: endAt,
                startOffset: startOffset,
                endOffset: endOffset
            )

        case let (.iso(startISO), .iso(endISO)):
            return resolveISO(type: type, startISO: startISO, endISO: endISO)

        default:
            return nil
        }
    }

    private static func resolveParsed(
        type: BookingType,
        startAt: Date,
        endAt: Date,
        startOffset: Int?,
        endOffset: Int?
    ) -> BookingDateWindow {
        switch type {
        case .hotel:
            return BookingDateWindow(
                startAt: HotelStayDate.calendarDay(fromParsed: startAt, offsetSeconds: startOffset),
                endAt: HotelStayDate.calendarDay(
                    fromParsed: endAt,
                    offsetSeconds: endOffset ?? startOffset
                ),
                hotelOffsetSeconds: startOffset ?? endOffset
            )
        case .flight, .ferry:
            return flightLikeWindow(
                startAt: startAt,
                endAt: endAt,
                startOffset: startOffset,
                endOffset: endOffset
            )
        case .activity, .carRental, .other:
            return BookingDateWindow(startAt: startAt, endAt: endAt)
        }
    }

    private static func resolveISO(
        type: BookingType,
        startISO: String,
        endISO: String
    ) -> BookingDateWindow? {
        switch type {
        case .hotel:
            guard let startDay = ISODateTime.dateOnly(fromISO: startISO),
                  let endDay = ISODateTime.dateOnly(fromISO: endISO) else {
                return nil
            }
            return BookingDateWindow(
                startAt: startDay.date,
                endAt: endDay.date,
                hotelOffsetSeconds: startDay.offsetSeconds ?? endDay.offsetSeconds
            )

        case .flight, .ferry:
            guard let clocks = wallClocks(startISO: startISO, endISO: endISO) else {
                return nil
            }
            return flightLikeWindow(
                startAt: clocks.start.wallClockAsUTC,
                endAt: clocks.end.wallClockAsUTC,
                startOffset: clocks.start.offsetSeconds,
                endOffset: clocks.end.offsetSeconds
            )

        case .activity, .carRental, .other:
            guard let clocks = wallClocks(startISO: startISO, endISO: endISO) else {
                return nil
            }
            return BookingDateWindow(
                startAt: clocks.start.wallClockAsUTC,
                endAt: clocks.end.wallClockAsUTC
            )
        }
    }

    private static func wallClocks(
        startISO: String,
        endISO: String
    ) -> (start: ISODateTime.WallClockStorage, end: ISODateTime.WallClockStorage)? {
        guard let start = ISODateTime.wallClockStorage(fromISO: startISO),
              let end = ISODateTime.wallClockStorage(fromISO: endISO) else {
            return nil
        }
        return (start, end)
    }

    private static func flightLikeWindow(
        startAt: Date,
        endAt: Date,
        startOffset: Int?,
        endOffset: Int?
    ) -> BookingDateWindow {
        BookingDateWindow(
            startAt: startAt,
            endAt: endAt,
            flightDepartureOffsetSeconds: startOffset,
            flightArrivalOffsetSeconds: endOffset
        )
    }
}
