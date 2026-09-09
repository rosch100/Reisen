import Foundation
import ReisenProviders

enum ExpediaAPI {
    static let origin = ExpediaSessionProbe.origin
    static let portalHost = ExpediaSessionProbe.portalHost
    static let loginURL = URL(string: "\(origin)/login")!
    static let tripsURL = ExpediaSessionProbe.tripsURL
    static let graphqlURL = URL(string: "\(origin)/graphql")!
}
