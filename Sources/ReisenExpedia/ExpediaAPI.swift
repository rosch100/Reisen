import Foundation
import ReisenProviders

enum ExpediaAPI {
    static let origin = ExpediaSessionProbe.origin
    static let portalHost = ExpediaSessionProbe.portalHost
    static let loginURL = URL(string: "\(origin)/login")!
    static let tripsURL = ExpediaSessionProbe.tripsURL
    /// Full URL literal (iOS binary isolation marker `www.expedia.de/graphql`).
    static let graphqlURL = URL(string: "https://www.expedia.de/graphql")!
}
