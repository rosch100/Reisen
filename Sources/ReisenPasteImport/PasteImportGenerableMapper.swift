import Foundation
import ReisenDomain

public enum PasteImportMapperError: Error, Equatable {
    /// Frist ohne verwertbares ISO8601-Datum.
    case invalidDeadlineDate(String?)
    /// Hinweis ohne Titel oder ohne Detail.
    case incompleteGuestHint
}

/// DTO → `PasteImportExtraction`. Einzige Quelle für Typ-, Datums- und Enum-Übersetzung.
///
/// Unbekannte Enum-Strings werden nicht auf einen Sammelfall gebogen: `bookingType` und `status`
/// bleiben `nil`, damit `PasteImportFilter` bzw. der Editor entscheiden.
public enum PasteImportGenerableMapper {
    public static func extractions(from payload: PasteImportPayloadDTO) throws -> [PasteImportExtraction] {
        try payload.bookings.map(extraction(from:))
    }

    public static func extraction(from dto: PasteImportBookingDTO) throws -> PasteImportExtraction {
        PasteImportExtraction(
            bookingType: dto.bookingType.flatMap(bookingType(from:)),
            startAt: date(from: dto.startAtISO8601),
            endAt: date(from: dto.endAtISO8601),
            title: NonEmpty.string(dto.title),
            confirmationCode: NonEmpty.string(dto.confirmationCode),
            externalUrl: NonEmpty.string(dto.externalUrl),
            locationFrom: NonEmpty.string(dto.locationFrom),
            locationTo: NonEmpty.string(dto.locationTo),
            locationFromAddress: NonEmpty.string(dto.locationFromAddress),
            locationToAddress: NonEmpty.string(dto.locationToAddress),
            operatorName: NonEmpty.string(dto.operatorName),
            status: dto.status.flatMap(status(from:)),
            hotelCheckInMinutes: dto.hotelCheckInMinutes,
            hotelCheckOutMinutes: dto.hotelCheckOutMinutes,
            hotelOffsetSeconds: dto.hotelOffsetSeconds,
            flightDepartureOffsetSeconds: dto.flightDepartureOffsetSeconds,
            flightArrivalOffsetSeconds: dto.flightArrivalOffsetSeconds,
            passengers: passengers(from: dto.passengers),
            guestHints: try dto.guestHints.map(guestHint(from:)),
            rateDetails: dto.rateDetails.map(rateDetails(from:)),
            deadlines: try dto.deadlines.map(deadline(from:))
        )
    }

    private static func bookingType(from raw: String) -> BookingType? {
        NonEmpty.string(raw).flatMap(BookingType.init(rawValue:))
    }

    private static func status(from raw: String) -> BookingStatus? {
        NonEmpty.string(raw).flatMap(BookingStatus.init(rawValue:))
    }

    /// `withInternetDateTime` deckt `…T10:00:00Z` ab, Modelle liefern teils Millisekunden.
    private static func date(from raw: String?) -> Date? {
        guard let text = NonEmpty.string(raw) else { return nil }
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: text) { return date }
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: text)
    }

    /// Fehlende `passengerNumber` ist die Position im Array (1..n), keine erfundene Zahl.
    private static func passengers(from dtos: [PasteImportPassengerDTO]) -> [BookingPassenger] {
        dtos.enumerated().map { offset, dto in
            BookingPassenger(
                passengerNumber: dto.passengerNumber ?? offset + 1,
                travellerType: NonEmpty.string(dto.travellerType)
                    .flatMap(TravellerType.init(rawValue:)) ?? .unknown,
                title: NonEmpty.string(dto.title),
                givenName: NonEmpty.string(dto.givenName),
                familyName: NonEmpty.string(dto.familyName),
                secondFamilyName: NonEmpty.string(dto.secondFamilyName),
                birthDate: date(from: dto.birthDateISO8601)
            )
        }
    }

    private static func guestHint(from dto: PasteImportGuestHintDTO) throws -> BookingGuestHint {
        guard let title = NonEmpty.string(dto.title), let detail = NonEmpty.string(dto.detail) else {
            throw PasteImportMapperError.incompleteGuestHint
        }
        return BookingGuestHint(
            title: title,
            detail: detail,
            sourceKey: "pasteImport:hint:\(title)"
        )
    }

    private static func rateDetails(from dto: PasteImportRateDetailsDTO) -> BookingRateDetails {
        var details = BookingRateDetails(
            totalPriceAmount: dto.totalPriceAmount,
            totalPriceCurrency: NonEmpty.string(dto.totalPriceCurrency),
            roomCategory: NonEmpty.string(dto.roomCategory),
            includedBreakfast: dto.includedBreakfast,
            guestCount: dto.guestCount,
            roomCount: dto.roomCount,
            airline: NonEmpty.string(dto.airline),
            passengerCount: dto.passengerCount,
            baggageInfoRaw: NonEmpty.string(dto.baggageInfoRaw)
        )
        if let boardType = NonEmpty.string(dto.boardType).flatMap(BookingBoardType.init(rawValue:)) {
            details.boardType = boardType
        }
        return details
    }

    private static func deadline(from dto: PasteImportDeadlineDTO) throws -> CancellationDeadline {
        guard let deadlineAt = date(from: dto.deadlineAtISO8601) else {
            throw PasteImportMapperError.invalidDeadlineDate(dto.deadlineAtISO8601)
        }
        var deadline = CancellationDeadline(
            deadlineAt: deadlineAt,
            policyText: NonEmpty.string(dto.policyText),
            hotelOffsetSeconds: dto.hotelOffsetSeconds,
            cancellationFeeAmount: dto.cancellationFeeAmount
        )
        if let isFreeCancellation = dto.isFreeCancellation {
            deadline.isFreeCancellation = isFreeCancellation
        }
        return deadline
    }
}
