import Foundation

extension OpodoFlightPassengersGraphQL {
    public static func getTripByTokenSupportAreaRequestBody(token: String) throws -> Data {
        try OpodoGraphQLRequest.body(
            query: """
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
            operationName: "getTripByTokenSupportArea",
            variables: ["token": token]
        )
    }

    public static func baggageInfoRequestBody(tripDetailsToken: String) throws -> Data {
        try OpodoGraphQLRequest.body(
            query: """
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
            operationName: "baggageInfo",
            variables: [
                "request": [
                    "tripDetailsToken": tripDetailsToken,
                ],
            ]
        )
    }
}
