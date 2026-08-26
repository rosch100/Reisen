import Foundation
import ReisenDomain
import ReisenProviders

extension Check24DeepLinkBuilder {
    func hotelDestinationParts(from destinationHint: String) throws -> (name: String, id: Int) {
        let parts = destinationHint.split(separator: "-")
        guard let last = parts.last, let destinationId = Int(last) else {
            throw DeepLinkIssue.destinationIdNotDerivable
        }
        let destinationName = parts.dropLast().joined(separator: "-")
        guard !destinationName.isEmpty else { throw DeepLinkIssue.destinationIdNotDerivable }
        return (destinationName, destinationId)
    }
}
