import Foundation
import ReisenProviders

@main
enum SyncIOSQuerySchemes {
    static func main() throws {
        guard CommandLine.arguments.count == 2 else {
            fputs("Usage: SyncIOSQuerySchemes <Info.plist path>\n", stderr)
            exit(1)
        }

        let plistURL = URL(fileURLWithPath: CommandLine.arguments[1])
        let data = try Data(contentsOf: plistURL)
        guard var plist = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            throw PlistError.invalidRoot
        }

        plist["LSApplicationQueriesSchemes"] = ProviderNativeApp.queryURLSchemes
        let output = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try output.write(to: plistURL, options: .atomic)
        print("OK: LSApplicationQueriesSchemes (\(ProviderNativeApp.queryURLSchemes.count) schemes)")
    }

    enum PlistError: Error {
        case invalidRoot
    }
}
