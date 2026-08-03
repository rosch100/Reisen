import Foundation
import ReisenDomain

extension DomainMapper {
    public static func passenger(from model: SDBookingPassenger) -> BookingPassenger {
        BookingPassenger(
            id: model.id,
            bookingID: model.passengerID,
            passengerNumber: model.passengerNumber,
            travellerType: TravellerType(rawValue: model.travellerTypeRaw ?? "") ?? .unknown,
            title: model.title,
            givenName: model.givenName,
            familyName: model.familyName,
            secondFamilyName: model.secondFamilyName,
            birthDate: model.birthDate,
            baggageAllowances: (model.baggageAllowances ?? []).map(baggageAllowance(from:))
        )
    }

    public static func baggageAllowance(from model: SDBaggageAllowance) -> BaggageAllowance {
        BaggageAllowance(
            id: model.id,
            passengerID: model.passenger?.id,
            type: BaggageType(rawValue: model.baggageTypeRaw) ?? .unknown,
            pieceCount: model.pieceCount,
            weightKg: model.weightKg,
            sectionID: model.sectionID,
            airlineCode: model.airlineCode,
            fromLabel: model.fromLabel,
            toLabel: model.toLabel
        )
    }
}
