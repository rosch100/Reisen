import Testing
import Foundation
import ReisenOpodo
import ReisenDomain

@Test("OpodoActivityListParser parst Buchungen aus HTML (flight + hotel)")
func opodoParsesFlightsAndHotels() throws {
    let html = """
    <html>
      <body>
        <a href="https://www.opodo.de/hotel/abc" data-start="2026-08-01" data-end="2026-08-05">Hotel ABC</a>
        <a href="https://www.opodo.de/flight/def" data-start="2026-08-10" data-end="2026-08-11">Flight DEF</a>
      </body>
    </html>
    """

    let bookings = try OpodoActivityListParser().parseBookings(from: html)
    #expect(bookings.count == 2)

    // Prüfe BookingType über URL-Heuristik.
    let typesByUrl = Dictionary(bookings.map { ($0.externalUrl, $0.bookingType) }, uniquingKeysWith: { $1 })
    #expect(typesByUrl["https://www.opodo.de/hotel/abc"] == .hotel)
    #expect(typesByUrl["https://www.opodo.de/flight/def"] == .flight)
}

@Test("OpodoActivityListParser wirft bei fehlenden Bookings")
func opodoThrowsWhenNoBookingsFound() {
    let html = "<html><body><p>no bookings</p></body></html>"
    #expect(throws: OpodoActivityListParserError.noBookingsFound) {
        _ = try OpodoActivityListParser().parseBookings(from: html)
    }
}

@Test("OpodoCancellationDeadlineParser erkennt Storno Datum aus HTML")
func opodoCancellationParserFindsDeadline() {
    let html = """
    <html><body>
      <div>
        Stornieren Sie kostenlos bis zum 13.07.2026 21:59 Uhr (Hotel-Ortszeit)
        <span>cancelation fee € 12,34</span>
      </div>
    </body></html>
    """

    let deadlines = OpodoCancellationDeadlineParser().parseDeadlines(from: html)
    #expect(deadlines.count >= 1)
    if let first = deadlines.first {
        #expect(first.isFreeCancellation == true)
    }
}

@Test("OpodoCancellationDeadlineParser erkennt Stornierungsrichtlinie mit Monatsname")
func opodoCancellationParserFindsGermanLongDate() throws {
    let html = """
    <html><body>
      <div>Andere Texte bis irgendwann</div>
      <section>Stornierungsrichtlinie Bis 1. August 2026 (Bis 22:00)</section>
    </body></html>
    """

    let deadlines = OpodoCancellationDeadlineParser().parseDeadlines(from: html)
    #expect(deadlines.count >= 1)
    let deadline = try #require(
        deadlines.first { ($0.policyText ?? "").contains("Stornierungsrichtlinie") } ?? deadlines.first
    )
    #expect(deadline.policyText?.contains("Stornierungsrichtlinie") == true)
    #expect(deadline.isFreeCancellation == true)

    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: deadline.deadlineAt)
    #expect(comps.year == 2026)
    #expect(comps.month == 8)
    #expect(comps.day == 1)
    #expect(comps.hour == 22)
    #expect(comps.minute == 0)
}

@Test("OpodoCancellationDeadlineParser akzeptiert Datum ohne Punkt und Vollständige Rückerstattung")
func opodoCancellationParserAcceptsDateWithoutDot() throws {
    let html = """
    Stornierungsrichtlinie Bis 1 August 2026 (Bis 22:00) - Vollständige Rückerstattung
    """
    let deadlines = OpodoCancellationDeadlineParser().parseDeadlines(from: html)
    let deadline = try #require(
        deadlines.first { ($0.policyText ?? "").localizedCaseInsensitiveContains("Stornierungsrichtlinie") }
    )
    #expect(deadline.isFreeCancellation == true)
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let comps = calendar.dateComponents([.month, .day, .hour], from: deadline.deadlineAt)
    #expect(comps.month == 8)
    #expect(comps.day == 1)
    #expect(comps.hour == 22)
}

@Test("OpodoCancellationDeadlineParser erkennt Monatsabkürzung mit Punkt (Aug.)")
func opodoCancellationParserAcceptsMonthAbbreviationWithDot() throws {
    let html = """
    <html><body>
      <div>
        Stornierungsrichtlinie Bis 1. Aug. 2026 (Bis 22:00) - Kostenlos stornierbar
      </div>
    </body></html>
    """

    let deadlines = OpodoCancellationDeadlineParser().parseDeadlines(from: html)
    let deadline = try #require(
        deadlines.first { ($0.policyText ?? "").localizedCaseInsensitiveContains("stornierungsrichtlinie") }
    )
    #expect(deadline.isFreeCancellation == true)

    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: deadline.deadlineAt)
    #expect(comps.year == 2026)
    #expect(comps.month == 8)
    #expect(comps.day == 1)
    #expect(comps.hour == 22)
    #expect(comps.minute == 0)
}

@Test("OpodoCancellationDeadlineParser toleriert kein Whitespace zwischen Monat und Jahr (Aug.2026)")
func opodoCancellationParserAcceptsNoWhitespaceBetweenMonthAndYear() {
    let html = """
    <html><body>
      <div>Stornierungsrichtlinie Bis 1. Aug.2026 (Bis 22:00) - Kostenlos stornierbar</div>
    </body></html>
    """

    let deadlines = OpodoCancellationDeadlineParser().parseDeadlines(from: html)
    let deadline = deadlines.first
    #expect(deadline != nil)
    if let deadline {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let comps = calendar.dateComponents([.month, .day], from: deadline.deadlineAt)
        #expect(comps.month == 8)
        #expect(comps.day == 1)
    }
}

@Test("OpodoCancellationDeadlineParser erkennt Monatsabkürzungen (Jan–Apr)")
func opodoCancellationParserUniversalMonthsJanApr() {
    opodoCancellationParserUniversalMonthsRange(tokens: [
        ("Jan.", 1),
        ("Feb.", 2),
        ("Mär.", 3),
        ("Apr.", 4),
    ])
}

@Test("OpodoCancellationDeadlineParser erkennt Monatsabkürzungen (Mai–Aug)")
func opodoCancellationParserUniversalMonthsMayAug() {
    opodoCancellationParserUniversalMonthsRange(tokens: [
        ("Mai.", 5),
        ("Jun.", 6),
        ("Jul.", 7),
        ("Aug.", 8),
    ])
}

@Test("OpodoCancellationDeadlineParser erkennt Monatsabkürzungen (Sep–Dez)")
func opodoCancellationParserUniversalMonthsSepDec() {
    opodoCancellationParserUniversalMonthsRange(tokens: [
        ("Sep.", 9),
        ("Okt.", 10),
        ("Nov.", 11),
        ("Dez.", 12),
    ])
}

private func opodoCancellationParserUniversalMonthsRange(tokens: [(String, Int)]) {
    for (token, expectedMonth) in tokens {
        let html = """
        <html><body>
          <div>Stornierungsrichtlinie Bis 1 \(token) 2026 (Bis 22:00)</div>
        </body></html>
        """

        let deadlines = OpodoCancellationDeadlineParser().parseDeadlines(from: html)
        let deadline = deadlines.first
        #expect(deadline != nil)

        if let deadline {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 0)!
            let comps = calendar.dateComponents([.month], from: deadline.deadlineAt)
            #expect(comps.month == expectedMonth)
        }
    }
}

