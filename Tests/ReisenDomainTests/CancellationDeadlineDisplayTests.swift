import Testing
import Foundation
import ReisenDomain

private func deDateTimeString(_ date: Date, timeZone: TimeZone) -> String {
    let df = DateFormatter()
    df.locale = Locale(identifier: "de_DE_POSIX")
    df.timeZone = timeZone
    df.dateFormat = "d.M. HH:mm"
    return df.string(from: date)
}

@Test("Display-Filter: abgelaufene Deadlines ausblenden + Vollpreis-Paid ausblenden")
func displayFilterHidesExpiredAndFullPricePaid() {
    let service = CancellationDeadlineDisplayService()
    let tz = TimeZone(secondsFromGMT: 0)!

    let calendar = Calendar(identifier: .gregorian)
    var comps = DateComponents()
    comps.year = 2026
    comps.month = 7
    comps.day = 24
    comps.hour = 10
    comps.minute = 0
    comps.timeZone = tz
    let now = calendar.date(from: comps)!

    let freeFuture = CancellationDeadline(
        id: UUID(),
        deadlineAt: calendar.date(byAdding: .day, value: 2, to: now)!,
        isFreeCancellation: true
    )

    let paidFull = CancellationDeadline(
        id: UUID(),
        deadlineAt: calendar.date(byAdding: .day, value: 3, to: now)!,
        isFreeCancellation: false,
        cancellationFeeAmount: 100
    )

    let paidPartial = CancellationDeadline(
        id: UUID(),
        deadlineAt: calendar.date(byAdding: .day, value: 4, to: now)!,
        isFreeCancellation: false,
        cancellationFeeAmount: 50
    )

    let paidExpired = CancellationDeadline(
        id: UUID(),
        deadlineAt: calendar.date(byAdding: .day, value: -1, to: now)!,
        isFreeCancellation: false,
        cancellationFeeAmount: 10
    )

    let result = service.deadlinesForDisplay([freeFuture, paidFull, paidPartial, paidExpired], now: now)

    #expect(result.contains(where: { $0.id == freeFuture.id }))
    #expect(!result.contains(where: { $0.id == paidFull.id }))
    #expect(result.contains(where: { $0.id == paidPartial.id }))
    #expect(!result.contains(where: { $0.id == paidExpired.id }))
}

@Test("Summary: Fix-Zeile wird gesetzt, wenn es keine zukünftige Free-Cancellation gibt (paid partial trotzdem)")
func summaryAddsFixWithoutFutureFree() {
    let service = CancellationDeadlineDisplayService()
    let tz = TimeZone(secondsFromGMT: 0)!

    let calendar = Calendar(identifier: .gregorian)
    var comps = DateComponents()
    comps.year = 2026
    comps.month = 7
    comps.day = 24
    comps.hour = 10
    comps.minute = 0
    comps.timeZone = tz
    let now = calendar.date(from: comps)!

    let paidFull = CancellationDeadline(
        id: UUID(),
        deadlineAt: calendar.date(byAdding: .day, value: 3, to: now)!,
        isFreeCancellation: false,
        cancellationFeeAmount: 100
    )

    let paidPartial = CancellationDeadline(
        id: UUID(),
        deadlineAt: calendar.date(byAdding: .day, value: 4, to: now)!,
        policyText: "Policy-Partial",
        isFreeCancellation: false,
        cancellationFeeAmount: 50
    )

    let lines = service.summaryLines(
        deadlines: [paidFull, paidPartial],
        hotelTimeZone: tz,
        now: now
    )

    #expect(lines.first?.kind == .fix)
    #expect(lines.first?.text == "Fix (nicht mehr kostenlos stornierbar)")

    #expect(lines.contains(where: { $0.kind == .paid && $0.id == paidPartial.id }))
    #expect(!lines.contains(where: { $0.kind == .paid && $0.id == paidFull.id }))
}

@Test("Urgenz: Schwellenwerte critical/warning/ok")
func urgencyThresholds() throws {
    let service = CancellationDeadlineDisplayService()
    let tz = TimeZone(secondsFromGMT: 0)!

    let calendar = Calendar(identifier: .gregorian)
    var comps = DateComponents()
    comps.year = 2026
    comps.month = 7
    comps.day = 24
    comps.hour = 10
    comps.minute = 0
    comps.timeZone = tz
    let now = calendar.date(from: comps)!

    let freeCritical = CancellationDeadline(
        id: UUID(),
        deadlineAt: calendar.date(byAdding: .day, value: 1, to: now)!,
        isFreeCancellation: true
    )

    let freeWarning = CancellationDeadline(
        id: UUID(),
        deadlineAt: calendar.date(byAdding: .day, value: 3, to: now)!,
        isFreeCancellation: true
    )

    let freeOk = CancellationDeadline(
        id: UUID(),
        deadlineAt: calendar.date(byAdding: .day, value: 6, to: now)!,
        isFreeCancellation: true
    )

    let lines = service.summaryLines(
        deadlines: [freeCritical, freeWarning, freeOk],
        hotelTimeZone: tz,
        now: now
    )

    let critical = try #require(lines.first(where: { $0.id == freeCritical.id }))
    #expect(critical.kind == .free)
    #expect(critical.urgency == .critical)

    let warning = try #require(lines.first(where: { $0.id == freeWarning.id }))
    #expect(warning.urgency == .warning)

    let ok = try #require(lines.first(where: { $0.id == freeOk.id }))
    #expect(ok.urgency == .ok)
}

@Test("Summary-Textformat: Free-Cancellation nutzt geplantes Datumsformat")
func summaryTextFormatsDateTime() throws {
    let service = CancellationDeadlineDisplayService()
    let tz = TimeZone(secondsFromGMT: 0)!

    let calendar = Calendar(identifier: .gregorian)
    var comps = DateComponents()
    comps.year = 2026
    comps.month = 7
    comps.day = 24
    comps.hour = 10
    comps.minute = 0
    comps.timeZone = tz
    let now = calendar.date(from: comps)!

    let deadlineAt = calendar.date(from: DateComponents(
        timeZone: tz,
        year: 2026,
        month: 7,
        day: 26,
        hour: 15,
        minute: 30
    ))!

    let free = CancellationDeadline(
        id: UUID(),
        deadlineAt: deadlineAt,
        isFreeCancellation: true
    )

    let lines = service.summaryLines(
        deadlines: [free],
        hotelTimeZone: tz,
        now: now
    )

    let line = try #require(lines.first(where: { $0.kind == .free }))
    let expectedDate = deDateTimeString(deadlineAt, timeZone: tz)
    #expect(line.text == "Kostenlos stornierbar bis \(expectedDate)")
}

