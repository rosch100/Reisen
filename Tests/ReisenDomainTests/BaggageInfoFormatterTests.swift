import Testing
import Foundation
import ReisenDomain

@Test func baggageInfoFormatterAggregatesWhenAllPassengersIdentical() {
    let passengers = [
        BookingPassenger(
            passengerNumber: 1,
            travellerType: .adult,
            baggageAllowances: [
                BaggageAllowance(
                    type: .checkedBag,
                    pieceCount: 1,
                    weightKg: 10
                ),
                BaggageAllowance(
                    type: .cabinBag,
                    pieceCount: 1,
                    weightKg: 5
                )
            ]
        ),
        BookingPassenger(
            passengerNumber: 2,
            travellerType: .adult,
            baggageAllowances: [
                BaggageAllowance(
                    type: .checkedBag,
                    pieceCount: 1,
                    weightKg: 10
                ),
                BaggageAllowance(
                    type: .cabinBag,
                    pieceCount: 1,
                    weightKg: 5
                )
            ]
        )
    ]

    let baggage = BaggageInfoFormatter.baggageInfoRaw(passengers: passengers)
    #expect(baggage.contains("Aufgabe") == true)
    #expect(baggage.contains("Hand") == true)
    #expect(baggage.contains("10KG") == true)
    #expect(baggage.contains("5KG") == true)
    #expect(baggage.contains("Pax") == false)
}

@Test func baggageInfoFormatterKeepsPaxLinesWhenPassengersDiffer() {
    let passengers = [
        BookingPassenger(
            passengerNumber: 1,
            travellerType: .adult,
            baggageAllowances: [
                BaggageAllowance(type: .checkedBag, pieceCount: 1, weightKg: 10)
            ]
        ),
        BookingPassenger(
            passengerNumber: 2,
            travellerType: .adult,
            baggageAllowances: [
                BaggageAllowance(type: .checkedBag, pieceCount: 1, weightKg: 6)
            ]
        )
    ]

    let baggage = BaggageInfoFormatter.baggageInfoRaw(passengers: passengers)
    #expect(baggage.contains("Pax 1:") == true)
    #expect(baggage.contains("Pax 2:") == true)
    #expect(baggage.contains("checkedBag") == false)
    #expect(baggage.contains("cabinBag") == false)
}

