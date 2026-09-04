import Foundation
import ReisenDomain

/// Launch-Vertrag für XCUI (`-UITesting` / `-UITestingEmpty`).
public enum UITestingMode: Equatable, Sendable {
    case off
    case populated
    case empty

    public var skipsSideEffects: Bool { self != .off }

    public static func from(
        arguments: [String],
        environment: [String: String] = [:]
    ) -> UITestingMode {
        if arguments.contains(UITestingLaunch.emptyArgument)
            || environment[UITestingLaunch.environmentKey] == UITestingLaunch.environmentEmpty {
            return .empty
        }
        if arguments.contains(UITestingLaunch.argument)
            || environment[UITestingLaunch.environmentKey] == UITestingLaunch.environmentPopulated {
            return .populated
        }
        return .off
    }

    public static var fromProcess: UITestingMode {
        from(
            arguments: ProcessInfo.processInfo.arguments,
            environment: ProcessInfo.processInfo.environment
        )
    }
}

public enum UITestingLaunch {
    public static let argument = "-UITesting"
    public static let emptyArgument = "-UITestingEmpty"
    public static let pasteImportArgument = "-UITestingPasteImport"
    public static let environmentKey = "REISEN_UITESTING"
    public static let environmentPopulated = "1"
    public static let environmentEmpty = "empty"
    public static let defaultsSuiteName = "app.voyenna.reisen.uitesting"
    public static let persistenceIgnoreStateArgument = "-ApplePersistenceIgnoreState"
    public static let treatUnknownArgumentsAsOpenArgument = "-NSTreatUnknownArgumentsAsOpen"

    public static var isActive: Bool {
        UITestingMode.fromProcess != .off
    }

    public static var shouldSeed: Bool {
        UITestingMode.fromProcess == .populated
    }

    public static var shouldInjectPasteImportFixture: Bool {
        isActive && ProcessInfo.processInfo.arguments.contains(pasteImportArgument)
    }

    public static func isActive(arguments: [String]) -> Bool {
        UITestingMode.from(arguments: arguments) != .off
    }

    public static func shouldSeed(arguments: [String]) -> Bool {
        UITestingMode.from(arguments: arguments) == .populated
    }

    public static func shouldInjectPasteImportFixture(arguments: [String]) -> Bool {
        UITestingMode.from(arguments: arguments) != .off
            && arguments.contains(pasteImportArgument)
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

    /// Populated-XCUI braucht aktive Portale (Cmd-1 / Sync-Chrome); Empty bleibt opt-in.
    public static func seedProviderEnablementIfNeeded(
        mode: UITestingMode,
        defaults: UserDefaults,
        syncProviderIDs: [ProviderID] = ProviderID.syncProviderIDs
    ) {
        guard mode == .populated else { return }
        for providerID in syncProviderIDs {
            defaults.set(true, forKey: AppSettingsKeys.providerEnabledKey(for: providerID))
        }
    }

    @MainActor
    public static let isolatedDefaults = makeIsolatedDefaults()
}
