import Foundation
import Testing
import ReisenDomain

/// Produktmarke und Bundle-Hierarchie (Spec `2026-09-04-voyenna-rebrand-design`).
enum VoyennaBrandingConfig {
    static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    static func plist(_ relativePath: String) throws -> [String: Any] {
        let data = try Data(contentsOf: repoRoot.appendingPathComponent(relativePath))
        let parsed = try PropertyListSerialization.propertyList(from: data, format: nil)
        guard let dict = parsed as? [String: Any] else {
            Issue.record("ungültiges Plist: \(relativePath)")
            return [:]
        }
        return dict
    }

    static func projectBundleIdentifiers() throws -> [String: String] {
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
}

@Test func voyennaBranding_macDisplayNameIsVoyenna() throws {
    let plist = try VoyennaBrandingConfig.plist("Resources/Info.plist")
    #expect(plist["CFBundleDisplayName"] as? String == "Voyenna")
    #expect(plist["CFBundleName"] as? String == "Voyenna")
    #expect(plist["CFBundleExecutable"] as? String == "Voyenna")
}

@Test func voyennaBranding_spmExecutableProductIsVoyenna() throws {
    let text = try String(
        contentsOf: VoyennaBrandingConfig.repoRoot.appendingPathComponent("Package.swift"),
        encoding: .utf8
    )
    #expect(text.contains(".executable(name: \"Voyenna\", targets: [\"Reisen\"])"))
}

@Test func voyennaBranding_buildAppScriptEmitsVoyennaBundle() throws {
    let text = try String(
        contentsOf: VoyennaBrandingConfig.repoRoot.appendingPathComponent("Scripts/build-app.sh"),
        encoding: .utf8
    )
    #expect(text.contains("APP_PRODUCT_NAME=\"Voyenna\""))
    #expect(text.contains("APP=\"$ROOT/.build/${APP_PRODUCT_NAME}.app\""))
    #expect(!text.contains(".build/Reisen.app"))
}

@Test func voyennaBranding_iosStoreDisplayNameIsVoyenna() throws {
    let plist = try VoyennaBrandingConfig.plist("Apps/ReiseniOS/Info.plist")
    #expect(plist["CFBundleDisplayName"] as? String == "Voyenna")
}

@Test func voyennaBranding_iosPrivateDisplayNameIsVoyennaSync() throws {
    let plist = try VoyennaBrandingConfig.plist("Apps/ReiseniOSPrivate/Info.plist")
    #expect(plist["CFBundleDisplayName"] as? String == "Voyenna Sync")
}

@Test func voyennaBranding_bundleHierarchyUsesVoyennaAppDomain() throws {
    let identifiers = try VoyennaBrandingConfig.projectBundleIdentifiers()
    #expect(identifiers["ReisenMac"] == "app.voyenna.reisen")
    #expect(identifiers["ReiseniOS"] == "app.voyenna.reisen.ios")
    #expect(identifiers["ReiseniOSPrivate"] == "app.voyenna.reisen.ios.private")

    let macEntitlements = try VoyennaBrandingConfig.plist("Resources/Reisen.entitlements")
    let containers = macEntitlements["com.apple.developer.icloud-container-identifiers"] as? [String] ?? []
    #expect(containers.contains("iCloud.app.voyenna.reisen"))
}

@Test func voyennaBranding_handoffSchemesAreVoyenna() {
    #expect(PasteImportHandoffIdentity.storeURLScheme == "voyenna")
    #expect(PasteImportHandoffIdentity.privateURLScheme == "voyenna-private")
}

@Test func voyennaBranding_applicationSupportFolderIsVoyenna() throws {
    let url = try #require(ReisenApplicationSupport.directoryURL())
    #expect(url.lastPathComponent == "Voyenna")
}

@Test func voyennaBranding_displayNameMatchesInfoPlist() throws {
    #expect(VoyennaBrand.displayName == "Voyenna")
    let plist = try VoyennaBrandingConfig.plist("Resources/Info.plist")
    #expect(plist["CFBundleDisplayName"] as? String == VoyennaBrand.displayName)
}

@Test func voyennaBranding_macIconUsesCFBundleIconFile() throws {
    let plist = try VoyennaBrandingConfig.plist("Resources/Info.plist")
    #expect(plist["CFBundleIconFile"] as? String == "AppIcon")
    let icns = VoyennaBrandingConfig.repoRoot.appendingPathComponent("Resources/AppIcon.icns")
    #expect(FileManager.default.fileExists(atPath: icns.path))
}

@Test func voyennaBranding_macAppDelegateDoesNotOverrideDockIconImage() throws {
    let source = try String(
        contentsOf: VoyennaBrandingConfig.repoRoot.appendingPathComponent("Sources/Reisen/App/AppDelegate.swift"),
        encoding: .utf8
    )
    #expect(!source.contains("NSApp.applicationIconImage"))
    #expect(!source.contains("applicationIconImage ="))
}
