import Foundation

enum ExpediaProviderError: Error, Equatable, Sendable {
    case missingWebViewSession
    case sessionNotAuthenticated
    case missingDUAID
    case graphqlHashRejected
    case graphqlErrors
    case invalidResponse
    case missingTripItemId
    case lodgingTripIdUndecodable
    case missingHotelCancellationURL
    case propertyTimeZoneUnresolved
}
