import Foundation

public extension Booking {
    var isAutoGap: Bool { provider == .autoGap }

    /// Eingabe für Gap-Detect / Completeness / Auto-Plan (kein Auto, nicht storniert).
    var isRealForGapDetect: Bool { !isAutoGap && status != .cancelled }
}
