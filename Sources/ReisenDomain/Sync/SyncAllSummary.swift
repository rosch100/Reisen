import Foundation

/// Ergebnis eines Einzel-Provider-Syncs innerhalb von Sync-All.
public enum ProviderSyncFinishOutcome: Equatable, Sendable {
    case fullSuccess
    case privacyRestricted
    case sideEffectFailure
}

/// Einordnung eines Einzel-Sync-Laufs für Sync-All-Zähler.
public enum SyncAllProviderRunBucket: Equatable, Sendable {
    case failure
    case fullSuccess
    case privacyRestricted
}

/// Zusammenfassung nach sequentiellem Sync mehrerer Provider.
public enum SyncAllSummary {
    public static func bucketProviderRun(
        errorMessage: String?,
        finishOutcome: ProviderSyncFinishOutcome?
    ) -> SyncAllProviderRunBucket {
        if errorMessage != nil {
            return .failure
        }
        switch finishOutcome {
        case .privacyRestricted:
            return .privacyRestricted
        case .fullSuccess, .none:
            return .fullSuccess
        case .sideEffectFailure:
            // Side-Effect-Fehler setzen normalerweise errorMessage; ohne Meldung trotzdem als Fehler zählen.
            return .failure
        }
    }

    public static func bucketProviderRun(_ outcome: ProviderSyncRunOutcome) -> SyncAllProviderRunBucket {
        bucketProviderRun(errorMessage: outcome.errorMessage, finishOutcome: outcome.finishOutcome)
    }

    public static func statusLine(successCount: Int, failureCount: Int) -> String {
        completionLine(
            fullSuccessCount: successCount,
            privacyRestrictedCount: 0,
            failureCount: failureCount
        )
    }

    public static func completionLine(
        fullSuccessCount: Int,
        privacyRestrictedCount: Int,
        failureCount: Int
    ) -> String {
        let parts = completionParts(
            fullSuccessCount: fullSuccessCount,
            privacyRestrictedCount: privacyRestrictedCount,
            failureCount: failureCount
        )
        if parts.isEmpty {
            return L10n.string(.syncAllFinished)
        }
        return L10n.format(.syncAllFinishedWithParts, parts.joined(separator: ", "))
    }

    public static func allProvidersSyncedLine(
        fullSuccessCount: Int,
        privacyRestrictedCount: Int
    ) -> String {
        let syncedCount = fullSuccessCount + privacyRestrictedCount
        if privacyRestrictedCount == 0 {
            return L10n.format(.syncAllAllProvidersSynced, syncedCount)
        }
        return completionLine(
            fullSuccessCount: fullSuccessCount,
            privacyRestrictedCount: privacyRestrictedCount,
            failureCount: 0
        )
    }

    public static func providerFailureMessage(errorMessage: String?) -> String {
        errorMessage ?? L10n.string(.syncUnknownError)
    }

    public static func sideEffectFailureMessages(
        base: String,
        detail: String
    ) -> (statusMessage: String, errorMessage: String) {
        let errorMessage = L10n.format(.syncSideEffectsError, detail)
        return ("\(base) \(errorMessage)", errorMessage)
    }

    public static func errorDetails(failures: [(providerName: String, message: String)]) -> String {
        failures
            .map { "\($0.providerName): \($0.message)" }
            .joined(separator: "\n")
    }

    private static func completionParts(
        fullSuccessCount: Int,
        privacyRestrictedCount: Int,
        failureCount: Int
    ) -> [String] {
        [
            countPart(fullSuccessCount, key: .syncAllPartOk),
            countPart(privacyRestrictedCount, key: .syncAllPartRestricted),
            countPart(failureCount, key: .syncAllPartFailed),
        ].compactMap(\.self)
    }

    private static func countPart(_ count: Int, key: L10nKey) -> String? {
        guard count > 0 else { return nil }
        return L10n.format(key, count)
    }
}

/// Ergebnis eines Einzel-Provider-Laufs innerhalb von Sync-All.
public struct ProviderSyncRunOutcome: Equatable, Sendable {
    public let providerName: String
    public let errorMessage: String?
    public let finishOutcome: ProviderSyncFinishOutcome?
    public let privacyPane: PrivacySettingPane?
    public let skippedPanes: [PrivacySettingPane]

    public init(
        providerName: String,
        errorMessage: String? = nil,
        finishOutcome: ProviderSyncFinishOutcome? = nil,
        privacyPane: PrivacySettingPane? = nil,
        skippedPanes: [PrivacySettingPane] = []
    ) {
        self.providerName = providerName
        self.errorMessage = errorMessage
        self.finishOutcome = finishOutcome
        self.privacyPane = privacyPane
        self.skippedPanes = skippedPanes
    }
}

/// UI-Zustand nach sequentiellem Sync-All (ohne plattformspezifische Privacy-Hints).
public enum SyncAllFinishPresentation: Equatable, Sendable {
    case allSucceeded(baseLine: String, skippedPrivacy: [PrivacySettingPane])
    case hasFailures(
        errorDetails: String,
        privacyPane: PrivacySettingPane?,
        completionLine: String
    )
}

/// Laufende Zählung für sequentiellen Sync-All-Abruf.
public struct SyncAllAggregation {
    public private(set) var fullSuccessCount = 0
    public private(set) var privacyRestrictedCount = 0
    public private(set) var failures: [(providerName: String, message: String)] = []
    public private(set) var skippedPrivacy: [PrivacySettingPane] = []
    public private(set) var lastPrivacyPane: PrivacySettingPane?

    public init() {}

    public var hasFailures: Bool { !failures.isEmpty }

    public var completionLine: String {
        SyncAllSummary.completionLine(
            fullSuccessCount: fullSuccessCount,
            privacyRestrictedCount: privacyRestrictedCount,
            failureCount: failures.count
        )
    }

    public var allSyncedBaseLine: String {
        SyncAllSummary.allProvidersSyncedLine(
            fullSuccessCount: fullSuccessCount,
            privacyRestrictedCount: privacyRestrictedCount
        )
    }

    public var finishPresentation: SyncAllFinishPresentation {
        if hasFailures {
            return .hasFailures(
                errorDetails: SyncAllSummary.errorDetails(failures: failures),
                privacyPane: lastPrivacyPane,
                completionLine: completionLine
            )
        }
        return .allSucceeded(
            baseLine: allSyncedBaseLine,
            skippedPrivacy: skippedPrivacy
        )
    }

    public mutating func recordProviderRun(_ outcome: ProviderSyncRunOutcome) {
        let bucket = SyncAllSummary.bucketProviderRun(outcome)
        switch bucket {
        case .failure:
            failures.append((
                outcome.providerName,
                SyncAllSummary.providerFailureMessage(errorMessage: outcome.errorMessage)
            ))
            lastPrivacyPane = outcome.privacyPane
        case .fullSuccess, .privacyRestricted:
            recordNonFailure(outcome, bucket: bucket)
        }
    }

    private mutating func recordNonFailure(
        _ outcome: ProviderSyncRunOutcome,
        bucket: SyncAllProviderRunBucket
    ) {
        switch bucket {
        case .fullSuccess:
            fullSuccessCount += 1
        case .privacyRestricted:
            privacyRestrictedCount += 1
        case .failure:
            return
        }
        skippedPrivacy.append(contentsOf: outcome.skippedPanes)
    }
}
