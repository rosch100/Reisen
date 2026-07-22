import Testing
import ReisenCheck24
import ReisenDomain
import Foundation

@Test("Check24 guestNames: parse HTML guestNames block")
func check24GuestNamesParses() {
    let html = """
    <div class="whatever">
      <div class="guestNames">Roland Schramme, Danila Liebe</div>
    </div>
    """

    let parsed = Check24FlightPassengersAndLuggageParser().guestNames(from: html)
    #expect(parsed == ["Roland Schramme", "Danila Liebe"])
}

@Test("Check24 status JSON: baggageAllowances maps types + aggregates flights")
func check24BaggageAllowancesFromStatusMapsAndAggregates() throws {
    let statusJSON = """
    {
      "httpstatuscode": 200,
      "success": true,
      "data": {
        "passengers": [
          {
            "title": "",
            "gender": "male",
            "firstname": "Roland",
            "surname": "Schramme",
            "birthday": "1968-07-09T00:00:00+01:00",
            "luggages": [],
            "type": "adt",
            "id": "dummy"
          }
        ],
        "itinerary": {
          "includedLuggageEqual": true,
          "flights": [
            { "includedLuggage": [
              { "type": "carry-on-small-bag", "pieces": 1, "weightKg": 0 },
              { "type": "carry-on-bag", "pieces": 1, "weightKg": 8 },
              { "type": "checked-bag", "pieces": 1, "weightKg": 10 }
            ]},
            { "includedLuggage": [
              { "type": "carry-on-small-bag", "pieces": 1, "weightKg": 0 },
              { "type": "carry-on-bag", "pieces": 1, "weightKg": 8 },
              { "type": "checked-bag", "pieces": 1, "weightKg": 10 }
            ]}
          ]
        }
      }
    }
    """

    let parser = Check24FlightPassengersAndLuggageParser()
    let allowances = try parser.baggageAllowances(from: statusJSON)

    // includedLuggageEqual=true ⇒ nur 1x pro Typ (nicht doppelt Hin+Rück).
    #expect(allowances.contains { $0.type == .personalItem && $0.pieceCount == 1 && $0.weightKg == nil })
    #expect(allowances.contains { $0.type == .cabinBag && $0.pieceCount == 1 && $0.weightKg == 8 })
    #expect(allowances.contains { $0.type == .checkedBag && $0.pieceCount == 1 && $0.weightKg == 10 })
}

@Test("Check24 status JSON: baggageAllowances aggregates when includedLuggageEqual=false")
func check24BaggageAllowancesAggregatesWhenIncludedLuggageNotEqual() throws {
    let statusJSON = """
    {
      "httpstatuscode": 200,
      "success": true,
      "data": {
        "passengers": [
          {
            "title": "",
            "gender": "male",
            "firstname": "Roland",
            "surname": "Schramme",
            "birthday": "1968-07-09T00:00:00+01:00",
            "luggages": [],
            "type": "adt",
            "id": "dummy"
          }
        ],
        "itinerary": {
          "includedLuggageEqual": false,
          "flights": [
            { "includedLuggage": [
              { "type": "carry-on-small-bag", "pieces": 1, "weightKg": 0 },
              { "type": "carry-on-bag", "pieces": 1, "weightKg": 8 },
              { "type": "checked-bag", "pieces": 1, "weightKg": 10 }
            ]},
            { "includedLuggage": [
              { "type": "carry-on-small-bag", "pieces": 1, "weightKg": 0 },
              { "type": "carry-on-bag", "pieces": 1, "weightKg": 8 },
              { "type": "checked-bag", "pieces": 1, "weightKg": 10 }
            ]}
          ]
        }
      }
    }
    """

    let parser = Check24FlightPassengersAndLuggageParser()
    let allowances = try parser.baggageAllowances(from: statusJSON)

    #expect(allowances.contains { $0.type == .personalItem && $0.pieceCount == 2 && $0.weightKg == nil })
    #expect(allowances.contains { $0.type == .cabinBag && $0.pieceCount == 2 && $0.weightKg == 8 })
    #expect(allowances.contains { $0.type == .checkedBag && $0.pieceCount == 2 && $0.weightKg == 10 })
}

@Test("Check24 buildPassengers: attaches baggage allowances per passenger")
func check24BuildPassengersAttachesBaggagePerPassenger() {
    let parser = Check24FlightPassengersAndLuggageParser()
    let guestNames = ["Roland Schramme", "Danila Liebe"]
    let allowances = [
        BaggageAllowance(type: .cabinBag, pieceCount: 1, weightKg: 8),
        BaggageAllowance(type: .personalItem, pieceCount: 1, weightKg: nil),
    ]

    let passengers = parser.buildPassengers(
        guestNames: guestNames,
        baggageAllowances: allowances,
        travellerType: .adult
    )

    #expect(passengers.count == 2)
    #expect(passengers[0].passengerNumber == 1)
    #expect(passengers[0].givenName == "Roland")
    #expect(passengers[0].familyName == "Schramme")
    #expect(passengers[0].baggageAllowances.count == 2)
    #expect(passengers[1].baggageAllowances.count == 2)
    // Ensure we copied baggage allowances (fresh IDs per passenger).
    #expect(passengers[0].baggageAllowances.map(\.id) != passengers[1].baggageAllowances.map(\.id))
}

