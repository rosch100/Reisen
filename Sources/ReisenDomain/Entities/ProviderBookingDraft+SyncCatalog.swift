import Foundation

extension Collection where Element == ProviderBookingDraft {
    public func partitionedByCancellation() -> (active: [ProviderBookingDraft], cancelledCount: Int) {
        var cancelledCount = 0
        var active: [ProviderBookingDraft] = []
        active.reserveCapacity(count)
        for draft in self {
            if draft.status == .cancelled {
                cancelledCount += 1
            } else {
                active.append(draft)
            }
        }
        return (active, cancelledCount)
    }

    public func missingDeadlinesHint(requiresDeadlines: Bool) -> Bool {
        let deadlineEligible = filter { $0.bookingType == .hotel || $0.bookingType == .other }
        return requiresDeadlines
            && !deadlineEligible.isEmpty
            && deadlineEligible.allSatisfy(\.deadlines.isEmpty)
    }
}
