import Foundation

enum ExpediaGraphQL {
    struct PersistedOperation: Sendable {
        let name: String
        let sha256Hash: String
        let pageID: String
    }

    static let tripItems = PersistedOperation(
        name: "SharedUIWeb_TripItemsQuery",
        sha256Hash: "c53c91d271e7644df446ce719e13209914e854d8ecfcd438c4849a65dcc03985",
        pageID: "page.Trip.Overview,U,80"
    )

    static let tripItem = PersistedOperation(
        name: "TripItemQuery",
        sha256Hash: "5f38e6230f36e0b3b3e2cd3fc58074ea17e7af32b03a2761adbb14a400e54df4",
        pageID: "page.Itin.Trips,U,80"
    )

    static let roomDetails = PersistedOperation(
        name: "RoomDetailsQuery",
        sha256Hash: "bc7cb5bfe81736ea198026138bdcaf65ebede6691f01b3d75540d7cc1df079ac",
        pageID: "page.Itin.Trips,U,80"
    )

    static let bookingServicingManage = PersistedOperation(
        name: "BookingServicingManageQuery",
        sha256Hash: "290ca1ec53212887b09bba72925619d90bd59f4e3f64ad3c1c6d6d480a98770f",
        pageID: "page.BookingServicing,U,80"
    )

    static func persistedBody(
        operation: PersistedOperation,
        variables: [String: Any]
    ) throws -> Data {
        try persistedBody(
            operationName: operation.name,
            sha256Hash: operation.sha256Hash,
            variables: variables
        )
    }

    static func persistedBody(
        operationName: String,
        sha256Hash: String,
        variables: [String: Any]
    ) throws -> Data {
        try JSONSerialization.data(
            withJSONObject: [
                "operationName": operationName,
                "variables": variables,
                "extensions": [
                    "persistedQuery": [
                        "version": 1,
                        "sha256Hash": sha256Hash,
                    ],
                ],
            ],
            options: []
        )
    }

    static func context(duaid: String, authState: String = "AUTHENTICATED") -> [String: Any] {
        [
            "siteId": 6,
            "locale": "de_DE",
            "eapid": 0,
            "tpid": 6,
            "currency": "EUR",
            "device": ["type": "DESKTOP"],
            "identity": [
                "duaid": duaid,
                "authState": authState,
            ],
            "privacyTrackingState": "CAN_NOT_TRACK",
        ]
    }

    static func decodeDataObject(from text: String) throws -> [String: Any] {
        guard let data = text.data(using: .utf8) else {
            throw ExpediaProviderError.invalidResponse
        }
        let json: Any
        do {
            json = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw ExpediaProviderError.invalidResponse
        }
        if let list = json as? [[String: Any]] {
            for part in list {
                if let errors = part["errors"] {
                    throw classifyGraphQLErrors(errors)
                }
            }
            for part in list {
                if let dataObj = part["data"] as? [String: Any] {
                    return dataObj
                }
            }
            throw ExpediaProviderError.invalidResponse
        }
        if let obj = json as? [String: Any] {
            if let errors = obj["errors"] {
                throw classifyGraphQLErrors(errors)
            }
            if let dataObj = obj["data"] as? [String: Any] {
                return dataObj
            }
        }
        throw ExpediaProviderError.invalidResponse
    }

    private static func classifyGraphQLErrors(_ errors: Any) -> ExpediaProviderError {
        let blob = String(describing: errors).lowercased()
        if blob.contains("persistedquerynotfound")
            || blob.contains("persistedquery")
            || blob.contains("persisted query")
        {
            return .graphqlHashRejected
        }
        return .graphqlErrors
    }
}
