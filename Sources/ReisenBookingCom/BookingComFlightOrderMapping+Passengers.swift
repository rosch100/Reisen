import Foundation
import ReisenDomain

extension BookingComFlightOrderParser {
    func passengers(from order: FlightOrderEnvelope) -> [BookingPassenger] {
        guard let segment = firstSegment(order) else { return [] }
        let checked = segment.travellerCheckedLuggage ?? []
        let cabin = segment.travellerCabinLuggage ?? []
        let travellers = order.passengers ?? []

        return travellers.enumerated().map { index, traveller in
            passenger(
                index: index,
                traveller: traveller,
                checked: checked,
                cabin: cabin
            )
        }
    }

    func passenger(
        index: Int,
        traveller: FlightPassenger,
        checked: [FlightTravellerLuggage],
        cabin: [FlightTravellerLuggage]
    ) -> BookingPassenger {
        let travellerReference = traveller.travellerReference ?? ""
        return BookingPassenger(
            passengerNumber: index + 1,
            travellerType: traveller.travellerType,
            title: nil,
            givenName: traveller.firstName,
            familyName: traveller.lastName,
            secondFamilyName: nil,
            birthDate: nil,
            baggageAllowances: baggageAllowances(
                travellerReference: travellerReference,
                checked: checked,
                cabin: cabin
            )
        )
    }
}
