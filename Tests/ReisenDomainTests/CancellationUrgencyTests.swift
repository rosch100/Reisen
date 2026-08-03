import Foundation
import Testing
import ReisenDomain

@Test func cancellationUrgency_daysLeft_thresholds() {
    let service = CancellationUrgencyService()
    #expect(service.urgency(daysLeft: 0) == .critical)
    #expect(service.urgency(daysLeft: 2) == .critical)
    #expect(service.urgency(daysLeft: 3) == .warning)
    #expect(service.urgency(daysLeft: 4) == .warning)
    #expect(service.urgency(daysLeft: 5) == .ok)
}

@Test func cancellationUrgency_paidOrExpired_isFix() {
    let service = CancellationUrgencyService()
    let now = Date()
    let paid = CancellationDeadline(
        id: UUID(),
        deadlineAt: now.addingTimeInterval(86_400 * 10),
        isFreeCancellation: false
    )
    let expired = CancellationDeadline(
        id: UUID(),
        deadlineAt: now.addingTimeInterval(-60),
        isFreeCancellation: true
    )
    #expect(service.urgency(for: paid, now: now) == .fix)
    #expect(service.urgency(for: expired, now: now) == .fix)
}

@Test func cancellationUrgency_labels_areStable() {
    #expect(CancellationUrgency.fix.label == "Fix")
    #expect(CancellationUrgency.critical.label == "Rot")
    #expect(CancellationUrgency.warning.label == "Orange")
    #expect(CancellationUrgency.ok.label == "")
}
