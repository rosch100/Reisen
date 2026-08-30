import Foundation

/// Launch-Vertrag für XCUI (`-UITesting` / `-UITestingEmpty`).
public enum UITestingMode: Equatable, Sendable {
    case off
    case populated
    case empty

    public var skipsSideEffects: Bool { self != .off }

    public static func from(arguments: [String]) -> UITestingMode {
        if arguments.contains(UITestingLaunch.emptyArgument) { return .empty }
        if arguments.contains(UITestingLaunch.argument) { return .populated }
        return .off
    }

    public static var fromProcess: UITestingMode {
        from(arguments: ProcessInfo.processInfo.arguments)
    }
}

public enum UITestingLaunch {
    public static let argument = "-UITesting"
    public static let emptyArgument = "-UITestingEmpty"
    public static let defaultsSuiteName = "de.reisen.Reisen.uitesting"
    public static let persistenceIgnoreStateArgument = "-ApplePersistenceIgnoreState"

    public static var isActive: Bool {
        UITestingMode.fromProcess != .off
    }

    public static var shouldSeed: Bool {
        UITestingMode.fromProcess == .populated
    }

    public static func isActive(arguments: [String]) -> Bool {
        UITestingMode.from(arguments: arguments) != .off
    }

    public static func shouldSeed(arguments: [String]) -> Bool {
        UITestingMode.from(arguments: arguments) == .populated
    }

    public static func makeIsolatedDefaults(
        suiteName: String = defaultsSuiteName
    ) -> UserDefaults {
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            preconditionFailure("UserDefaults-Suite \(suiteName) konnte nicht geöffnet werden.")
        }
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    @MainActor
    public static let isolatedDefaults = makeIsolatedDefaults()
}
