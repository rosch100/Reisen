import Testing
import Foundation
import ReisenOpodo
import ReisenDomain

@Test("OpodoFlightPassengersGraphQL join: travellers + baggageInfo ergibt strukturierte Passagiere")
func opodoFlightPassengersJoinTravellersAndBaggage() throws {
    let travellersJSON = """
    {
      "data": {
        "getTripByToken": {
          "trip": {
            "travellers": [
              {
                "travellerType": "ADULT",
                "name": "Anna",
                "title": "MR",
                "firstLastName": "Example",
                "secondLastName": null,
                "birthDate": "1980-01-01T00:00:00+01:00"
              },
              {
                "travellerType": "ADULT",
                "name": "Ben",
                "title": "MR",
                "firstLastName": "Sample",
                "secondLastName": null,
                "birthDate": "2015-06-15T00:00:00+01:00"
              }
            ]
          }
        }
      }
    }
    """

    let baggageJSON = """
    {
      "data": {
        "baggageInfo": {
          "travellers": [
            {
              "numPassenger": 1,
              "sections": [
                {
                  "id": "152",
                  "airlineCode": "8B",
                  "baggageList": [
                    {
                      "type": "CHECKED_BAG",
                      "numPieces": 1,
                      "weight": -1
                    }
                  ]
                }
              ]
            },
            {
              "numPassenger": 2,
              "sections": [
                {
                  "id": "152",
                  "airlineCode": "8B",
                  "baggageList": [
                    {
                      "type": "CABIN_BAG",
                      "numPieces": 1,
                      "weight": 7.5
                    }
                  ]
                }
              ]
            }
          ]
        }
      }
    }
    """

    let passengers = try OpodoFlightPassengersGraphQL.parsePassengersAndBaggage(
        travellersJSON: travellersJSON,
        baggageJSON: baggageJSON
    )

    #expect(passengers.count == 2)

    let p1 = try #require(passengers.first { $0.passengerNumber == 1 })
    #expect(p1.travellerType == .adult)
    #expect(p1.title == "MR")
    #expect(p1.givenName == "Anna")
    #expect(p1.familyName == "Example")
    #expect(p1.baggageAllowances.count == 1)

    let a1 = try #require(p1.baggageAllowances.first)
    #expect(a1.type == .checkedBag)
    #expect(a1.pieceCount == 1)
    #expect(a1.weightKg == nil) // -1 → nil
    #expect(a1.sectionID == "152")
    #expect(a1.airlineCode == "8B")

    let p2 = try #require(passengers.first { $0.passengerNumber == 2 })
    #expect(p2.baggageAllowances.count == 1)
    let a2 = try #require(p2.baggageAllowances.first)
    #expect(a2.type == .cabinBag)
    #expect(a2.weightKg == 7.5)
}

