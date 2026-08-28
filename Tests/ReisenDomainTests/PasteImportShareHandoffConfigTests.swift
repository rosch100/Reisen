import Foundation
import Testing
import ReisenDomain

/// Konfiguration der Share-Übergabe: URL-Scheme, App Group und Anzeigename der Extension.
private enum PasteImportShareConfig {
    static let appGroup = "group.de.reisen.Reisen.pasteimport"
    static let urlScheme = "reisen"

    static let appEntitlements = [
        "Apps/ReiseniOS/ReiseniOS.entitlements",
        "Apps/ReiseniOS/ReiseniOS-Release.entitlements",
        "Apps/ReiseniOSPrivate/ReiseniOSPrivate.entitlements",
        "Apps/ReiseniOSPrivate/ReiseniOSPrivate-Release.entitlements",
        "Apps/ReisenPasteImportShare/ReisenPasteImportShare.entitlements",
    ]

    static let appInfoPlists = [
        "Apps/ReiseniOS/Info.plist",
        "Apps/ReiseniOSPrivate/Info.plist",
    ]

    static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // Tests/ReisenDomainTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // repo root
    }

    static func plist(_ relativePath: String) throws -> [String: Any] {
        let data = try Data(contentsOf: repoRoot.appendingPathComponent(relativePath))
        let parsed = try PropertyListSerialization.propertyList(from: data, format: nil)
        guard let plist = parsed as? [String: Any] else {
            throw PlistError.invalidRoot(relativePath)
        }
        return plist
    }

    /// Katalogwert ohne `L10n.locale` zu verstellen — der globale Locale-Zustand gehört den L10n-Tests.
    static func germanCatalogValue(for key: L10nKey) throws -> String {
        let url = repoRoot.appendingPathComponent("Sources/ReisenDomain/Resources/Localizable.xcstrings")
        let json = try JSONSerialization.jsonObject(with: try Data(contentsOf: url))
        guard let root = json as? [String: Any],
              let strings = root["strings"] as? [String: Any],
              let entry = strings[key.rawValue] as? [String: Any],
              let localizations = entry["localizations"] as? [String: Any],
              let german = localizations["de"] as? [String: Any],
              let unit = german["stringUnit"] as? [String: Any],
              let value = unit["value"] as? String
        else {
            throw PlistError.missingCatalogValue(key.rawValue)
        }
        return value
    }

    /// Bundle-IDs pro Target aus `project.yml` — die Datei ist SSOT der Xcode-Konfiguration.
    static func bundleIdentifiers() throws -> [String: String] {
        let text = try String(
            contentsOf: repoRoot.appendingPathComponent("project.yml"),
            encoding: .utf8
        )
        var identifiers: [String: String] = [:]
        var section = ""
        var target = ""
        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            if !line.hasPrefix(" "), line.hasSuffix(":") {
                section = String(line.dropLast())
                target = ""
            } else if section == "targets", line.hasPrefix("  "), !line.hasPrefix("   "),
                      line.hasSuffix(":") {
                target = line.trimmingCharacters(in: .whitespaces).dropLast().description
            } else if !target.isEmpty,
                      let range = line.range(of: "PRODUCT_BUNDLE_IDENTIFIER:") {
                identifiers[target] = line[range.upperBound...]
                    .trimmingCharacters(in: .whitespaces)
            }
        }
        return identifiers
    }

    enum PlistError: Error {
        case invalidRoot(String)
        case missingCatalogValue(String)
    }
}

@Test func pasteImportShare_bothAppsDeclareHandoffURLScheme() throws {
    for path in PasteImportShareConfig.appInfoPlists {
        let plist = try PasteImportShareConfig.plist(path)
        let urlTypes = plist["CFBundleURLTypes"] as? [[String: Any]] ?? []
        let schemes = urlTypes.flatMap { $0["CFBundleURLSchemes"] as? [String] ?? [] }
        #expect(schemes.contains(PasteImportShareConfig.urlScheme), "\(path) ohne Scheme reisen")
    }
}

@Test func pasteImportShare_appsAndExtensionShareAppGroup() throws {
    for path in PasteImportShareConfig.appEntitlements {
        let plist = try PasteImportShareConfig.plist(path)
        let groups = plist["com.apple.security.application-groups"] as? [String] ?? []
        #expect(groups.contains(PasteImportShareConfig.appGroup), "\(path) ohne App Group")
    }
}

@Test func pasteImportShare_displayNameComesFromCatalog() throws {
    let plist = try PasteImportShareConfig.plist("Apps/ReisenPasteImportShare/Info.plist")
    let expected = try PasteImportShareConfig.germanCatalogValue(for: .pasteImportShareDisplayName)
    #expect(plist["CFBundleDisplayName"] as? String == expected)
}

/// iOS lehnt eine eingebettete Extension ab, deren Bundle-ID nicht mit der der Host-App beginnt.
@Test func pasteImportShare_extensionBundleIdsAreNestedUnderHostApps() throws {
    let identifiers = try PasteImportShareConfig.bundleIdentifiers()
    let hosts = [
        "ReiseniOS": "ReisenPasteImportShare",
        "ReiseniOSPrivate": "ReisenPasteImportSharePrivate",
    ]
    for (app, extensionTarget) in hosts {
        let appID = try #require(identifiers[app])
        let extensionID = try #require(identifiers[extensionTarget])
        #expect(extensionID.hasPrefix(appID + "."), "\(extensionID) liegt nicht unter \(appID)")
    }
}

@Test func pasteImportShare_activationCoversTextImagePDFAndFileURL() throws {
    let plist = try PasteImportShareConfig.plist("Apps/ReisenPasteImportShare/Info.plist")
    let extensionDict = plist["NSExtension"] as? [String: Any] ?? [:]
    #expect(extensionDict["NSExtensionPointIdentifier"] as? String == "com.apple.share-services")

    let attributes = extensionDict["NSExtensionAttributes"] as? [String: Any] ?? [:]
    let rule = attributes["NSExtensionActivationRule"] as? String ?? ""
    #expect(rule.contains("public.plain-text"))
    #expect(rule.contains("public.image"))
    #expect(rule.contains("com.adobe.pdf"))
    #expect(rule.contains("public.file-url"))
    #expect(!rule.contains("NSExtensionActivationSupportsFileWithMaxCount"))
    #expect(!rule.contains("NSExtensionActivationSupportsWebURLWithMaxCount"))
}
