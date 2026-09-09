import Foundation

/// Decision for Hotel RoomDetails side-path errors (SSOT for TravelProvider + tests).
enum ExpediaHotelSidePath {
    enum RoomDetailsHandling: Equatable {
        case softContinue
        case hardFail
    }

    static func roomDetailsHandling(for error: Error) -> RoomDetailsHandling {
        if error is CancellationError {
            return .hardFail
        }
        if let providerError = error as? ExpediaProviderError {
            switch providerError {
            case .graphqlHashRejected, .graphqlErrors:
                return .hardFail
            case .missingWebViewSession,
                 .sessionNotAuthenticated,
                 .missingDUAID,
                 .invalidResponse,
                 .missingTripItemId,
                 .lodgingTripIdUndecodable,
                 .missingHotelCancellationURL,
                 .propertyTimeZoneUnresolved:
                return .softContinue
            }
        }
        return .softContinue
    }
}
