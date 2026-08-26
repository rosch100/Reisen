import Foundation

extension ActivityListParser {
    func cityAddressPart(city: String?, postalCode: String?) -> String? {
        let c = nonEmptyAddressPart(city)
        let z = nonEmptyAddressPart(postalCode)
        switch (c, z) {
        case let (c?, z?): return "\(z) \(c)"
        case let (c?, nil): return c
        case let (nil, z?): return z
        default: return nil
        }
    }
}
