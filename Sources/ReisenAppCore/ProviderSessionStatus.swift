import Foundation

/// App-übergreifender Status der Provider-Session (Login/ready).
public enum ProviderSessionStatus: Equatable {
    case needsLogin
    case sessionReady
}

