import Foundation
import ReisenDomain

/// DTO → `PasteImportExtraction`. Einzige Quelle für Typ-, Datums- und Enum-Übersetzung.
///
/// Unbekannte Enum-Strings werden nicht auf einen Sammelfall gebogen: `bookingType` und `status`
/// bleiben `nil`, damit `PasteImportFilter` bzw. der Editor entscheiden.
/// Bekannte DE/EN-Aliase (`Flug`, `Tour`, `Mietwagen`) und Ticket-Datumsformate
/// (`28.08.2026 09:02`, `Sat, 8 Aug 2026 07:45`) übersetzt `PasteImportBookingLabel` /
/// `PasteImportTicketDate` — das ist keine Schätzung fehlender Werte.
///
/// Ein unvollständiger Hinweis oder eine Frist ohne Datum verwirft nur sich selbst und nicht die
/// ganze Buchung: ein einzelnes Detail, das das Modell halb erkannt hat, darf einen erkannten
/// Flug nicht mitreißen. Der Nutzer bestätigt ohnehin jeden Kandidaten im Editor.
public enum PasteImportGenerableMapper {
    public static func extractions(from payload: PasteImportPayloadDTO) -> [PasteImportExtraction] {
        payload.bookings.map(extraction(from:))
    }

    public static func extraction(from dto: PasteImportBookingDTO) -> PasteImportExtraction {
        PasteImportExtraction(
            bookingType: dto.bookingType.flatMap(PasteImportBookingLabel.bookingType(from:)),
            startAt: PasteImportTicketDate.parse(dto.startAtISO8601),
            endAt: PasteImportTicketDate.parse(dto.endAtISO8601),
            title: NonEmpty.string(dto.title),
            confirmationCode: PasteImportConfirmationCode.sanitize(dto.confirmationCode),
            externalUrl: NonEmpty.string(dto.externalUrl),
            locationFrom: NonEmpty.string(dto.locationFrom),
            locationTo: NonEmpty.string(dto.locationTo),
            locationFromAddress: NonEmpty.string(dto.locationFromAddress),
            locationToAddress: NonEmpty.string(dto.locationToAddress),
            operatorName: NonEmpty.string(dto.operatorName),
            status: dto.status.flatMap(PasteImportBookingLabel.status(from:)),
            hotelCheckInMinutes: dto.hotelCheckInMinutes,
            hotelCheckOutMinutes: dto.hotelCheckOutMinutes,
            hotelOffsetSeconds: dto.hotelOffsetSeconds,
            flightDepartureOffsetSeconds: dto.flightDepartureOffsetSeconds,
            flightArrivalOffsetSeconds: dto.flightArrivalOffsetSeconds,
            passengers: passengers(from: dto.passengers),
            guestHints: dto.guestHints.compactMap(guestHint(from:)),
            rateDetails: dto.rateDetails.map(rateDetails(from:)),
            deadlines: dto.deadlines.compactMap(deadline(from:))
        )
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
                birthDate: PasteImportTicketDate.parse(dto.birthDateISO8601)
            )
        }
    }

    /// `nil` verwirft den Hinweis: ohne Titel oder Detail steht im Editor nichts Prüfbares.
    private static func guestHint(from dto: PasteImportGuestHintDTO) -> BookingGuestHint? {
        guard let title = NonEmpty.string(dto.title), let detail = NonEmpty.string(dto.detail) else {
            return nil
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

    /// `nil` verwirft die Frist: ohne Datum ist sie weder anzeigbar noch erinnerbar.
    private static func deadline(from dto: PasteImportDeadlineDTO) -> CancellationDeadline? {
        guard let deadlineAt = PasteImportTicketDate.parse(dto.deadlineAtISO8601) else { return nil }
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
