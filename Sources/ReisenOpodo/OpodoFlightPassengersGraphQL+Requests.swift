import Foundation

extension OpodoFlightPassengersGraphQL {
    public static func getTripByTokenSupportAreaRequestBody(token: String) throws -> Data {
        let payload: [String: Any] = [
            "query": """
            query getTripByTokenSupportArea($token: String!) {
              getTripByToken(token: $token) {
                trip {
                  travellers {
                    travellerType
                    name
                    title
                    firstLastName
                    secondLastName
                    birthDate
                  }
                }
              }
            }
            """,
            "operationName": "getTripByTokenSupportArea",
            "variables": [
                "token": token,
            ],
        ]
        return try JSONSerialization.data(withJSONObject: payload, options: [])
    }

    public static func baggageInfoRequestBody(tripDetailsToken: String) throws -> Data {
        let payload: [String: Any] = [
            "query": """
            query baggageInfo($request: BookingBaggageInfoRequest!) {
              baggageInfo(request: $request) {
                travellers {
                  numPassenger
                  sections {
                    id
                    airlineCode
                    baggageList {
                      type
                      numPieces
                      weight
                      dimensions { length width height }
                    }
                  }
                }
              }
            }
            """,
            "operationName": "baggageInfo",
            "variables": [
                "request": [
                    "tripDetailsToken": tripDetailsToken,
                ],
            ],
        ]
        return try JSONSerialization.data(withJSONObject: payload, options: [])
    }
}
