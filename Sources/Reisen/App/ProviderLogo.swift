import SwiftUI
import AppKit
import Foundation
import ReisenDomain

struct ProviderLogo: View {
    let providerID: ProviderID

    var body: some View {
        if let nsImage = Self.loadImage(for: providerID) {
            Image(nsImage: nsImage)
                .resizable()
                .scaledToFit()
                .frame(width: 40, height: 16)
                .accessibilityLabel(Text("\(providerID.rawValue) logo"))
        } else {
            Image(systemName: "questionmark.circle")
                .foregroundStyle(.secondary)
                .imageScale(.small)
                .frame(width: 40, height: 16)
                .accessibilityLabel(Text("\(providerID.rawValue) logo (missing asset)"))
        }
    }

    /// SwiftPM `.process("Resources")` legt Dateien flach unter `Resources/` ab
    /// (ohne den Quell-Unterordner `ProviderLogos` als Bundle-Subdirectory).
    ///
    /// Kein `Bundle.module`: dessen Accessor `fatalError`t, wenn `Reisen_Reisen.bundle`
    /// nicht gefunden wird (Crash-Report: resource_bundle_accessor.swift).
    static func imageURL(for providerID: ProviderID, in bundle: Bundle? = nil) -> URL? {
        let bundles: [Bundle] = {
            if let bundle { return [bundle] }
            return resourceBundles()
        }()

        for candidate in bundles {
            if let url = candidate.url(forResource: providerID.rawValue, withExtension: "svg") {
                return url
            }
            if let url = candidate.url(
                forResource: providerID.rawValue,
                withExtension: "svg",
                subdirectory: "ProviderLogos"
            ) {
                return url
            }
        }
        return nil
    }

    private static func loadImage(for providerID: ProviderID) -> NSImage? {
        guard let url = imageURL(for: providerID) else { return nil }
        return NSImage(contentsOf: url)
    }

    static func nsImage(for providerID: ProviderID) -> NSImage? {
        loadImage(for: providerID)
    }

    /// Kandidaten analog SPM `resource_bundle_accessor`, aber ohne `fatalError`.
    private static func resourceBundles() -> [Bundle] {
        var result: [Bundle] = []
        var seen = Set<String>()

        func append(_ bundle: Bundle?) {
            guard let bundle else { return }
            let id = bundle.bundleURL.absoluteString
            guard seen.insert(id).inserted else { return }
            result.append(bundle)
        }

        let bundleName = "Reisen_Reisen.bundle"
        let roots: [URL] = [
            Bundle.main.resourceURL,
            Bundle.main.bundleURL,
            Bundle.main.bundleURL.deletingLastPathComponent(),
        ].compactMap { $0 }

        for root in roots {
            append(Bundle(url: root.appendingPathComponent(bundleName)))
        }

        // Flat-SVGs direkt in App-Resources (build-app.sh) oder SPM-Debug neben dem Binary.
        append(Bundle.main)

        return result
    }
}
