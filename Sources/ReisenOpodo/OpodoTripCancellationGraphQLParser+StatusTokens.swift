import Foundation

extension OpodoTripCancellationGraphQLParser {
    public static func isCancelledStatusToken(_ raw: String) -> Bool {
        let token = raw.uppercased()
        if token.contains("CANCELLABLE") || token.contains("CANCELABLE") {
            return false
        }
        if token.contains("CANCELLED") || token.contains("CANCELED") {
            return true
        }
        // Opodo BookingStatus (HAR Schema): stornierte Hotels kommen als RETAINED/FINAL_RET,
        // nicht als CANCELLED. Trip-Ebene bleibt oft CONTRACT.
        if token == "RETAINED" || token == "FINAL_RET" {
            return true
        }
        if token == "DIDNOTBUY" || token == "DID_NOT_BUY" || token == "VOID" {
            return true
        }
        // Reine Tokens wie "CANCEL" / "CANCELED_BY_USER"
        if token == "CANCEL" || token.hasPrefix("CANCEL_") || token.hasSuffix("_CANCEL") {
            return true
        }
        return false
    }
}
