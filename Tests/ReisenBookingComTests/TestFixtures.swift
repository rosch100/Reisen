import Foundation

/// SPM-Resource-Bundle dieses Test-Targets (`resources: .copy("Fixtures")`).
enum TestFixtures {
    enum Error: Swift.Error, CustomStringConvertible {
        case missing(String)

        var description: String {
            switch self {
            case .missing(let name):
                return "Test-Fixture fehlt im Resource-Bundle: \(name)"
            }
        }
    }

    static func text(_ name: String) throws -> String {
        try String(contentsOf: url(named: name), encoding: .utf8)
    }

    static func url(named name: String) throws -> URL {
        let (base, ext) = resourceParts(name)
        guard let url = Bundle.module.url(
            forResource: base,
            withExtension: ext,
            subdirectory: "Fixtures"
        ) else {
            throw Error.missing(name)
        }
        return url
    }

    private static func resourceParts(_ name: String) -> (String, String?) {
        guard let range = name.range(of: ".", options: .backwards),
              range.lowerBound > name.startIndex
        else {
            return (name, nil)
        }
        return (String(name[..<range.lowerBound]), String(name[range.upperBound...]))
    }
}
