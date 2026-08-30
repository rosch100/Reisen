import Testing
import Foundation
@testable import ReisenOpodo
import ReisenDomain
import ReisenProviders

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
    #expect(bookings.allSatisfy { $0.cancellationUrl == nil })
}

@Test("OpodoActivityListParser ignoriert Upsell- und Mietwagen-Links")
func opodoHTMLSkipsNonFlightHotel() throws {
    let html = """
    <html>
      <body>
        <a href="https://www.opodo.de/cars/xyz" data-start="2026-08-01" data-end="2026-08-05">Mietwagen</a>
        <a href="https://www.opodo.de/transfer/abc" data-start="2026-08-01" data-end="2026-08-02">Transfer</a>
        <a href="https://www.opodo.de/hotel/stay" data-start="2026-08-01" data-end="2026-08-05">Hotel</a>
      </body>
    </html>
    """
    let bookings = try OpodoActivityListParser().parseBookings(from: html)
    #expect(bookings.count == 1)
    #expect(bookings[0].bookingType == .hotel)
    #expect(bookings[0].externalUrl == "https://www.opodo.de/hotel/stay")
}

@Test("Opodo: Login-HTML wird als fehlende Session erkannt")
func opodoLoginHTMLIndicatesMissingSession() {
    let loginHTML = """
    <html><body>
    <form action="https://www.opodo.de/user/login">
    <input type="password" name="password">
    </form>
    </body></html>
    """
    #expect(AuthPageHTMLHeuristic.opodoLooksLikeLoginHTML(loginHTML))
    #expect(!AuthPageHTMLHeuristic.opodoLooksLikeLoginHTML(
        "<html><body><a href=\"https://www.opodo.de/travel/secure/\">Trips</a></body></html>"
    ))
}

@Test("OpodoActivityListParser liefert leeren Katalog statt Fehler")
func opodoEmptyHTMLIsEmptyCatalog() throws {
    let html = "<html><body><p>no bookings</p></body></html>"
    let bookings = try OpodoActivityListParser().parseBookings(from: html)
    #expect(bookings.isEmpty)
}

@Test("OpodoCancellationDeadlineParser erkennt Storno Datum aus HTML")
func opodoCancellationParserFindsDeadline() {
    let html = """
    <html><body>
      <div>
        Cancel for free until 13.07.2026 21:59 (property local time)
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

@Test("OpodoCancellationDeadlineParser erkennt EN-Cancellation-Policy mit Monatsname")
func opodoCancellationParserFindsEnglishLongDate() throws {
    let html = """
    <html><body>
      <div>Other text until someday</div>
      <section>Cancellation policy until 1 August 2026 (until 22:00) - free cancellation</section>
    </body></html>
    """

    let deadlines = OpodoCancellationDeadlineParser().parseDeadlines(from: html)
    #expect(deadlines.count >= 1)
    let deadline = try #require(
        deadlines.first { ($0.policyText ?? "").localizedCaseInsensitiveContains("cancellation policy") }
            ?? deadlines.first
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

@Test("OpodoCancellationDeadlineParser akzeptiert EN-Datum ohne Punkt")
func opodoCancellationParserAcceptsEnglishDateWithoutDot() throws {
    let html = """
    Cancellation policy until 1 August 2026 (until 22:00) - full refund
    """
    let deadlines = OpodoCancellationDeadlineParser().parseDeadlines(from: html)
    let deadline = try #require(
        deadlines.first { ($0.policyText ?? "").localizedCaseInsensitiveContains("cancellation policy") }
    )
    #expect(deadline.isFreeCancellation == true)
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let comps = calendar.dateComponents([.month, .day, .hour], from: deadline.deadlineAt)
    #expect(comps.month == 8)
    #expect(comps.day == 1)
    #expect(comps.hour == 22)
}

@Test("OpodoCancellationDeadlineParser erkennt EN-Monatsabkürzung (Aug.)")
func opodoCancellationParserAcceptsEnglishMonthAbbreviation() throws {
    let html = """
    <html><body>
      <div>
        Cancellation policy until 1 Aug. 2026 (until 22:00) - free cancellation
      </div>
    </body></html>
    """

    let deadlines = OpodoCancellationDeadlineParser().parseDeadlines(from: html)
    let deadline = try #require(
        deadlines.first { ($0.policyText ?? "").localizedCaseInsensitiveContains("cancellation policy") }
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
      <div>Cancellation policy until 1 Aug.2026 (until 22:00) - free cancellation</div>
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
        ("January", 1),
        ("February", 2),
        ("March", 3),
        ("April", 4),
    ])
}

@Test("OpodoCancellationDeadlineParser erkennt Monatsabkürzungen (May–Aug)")
func opodoCancellationParserUniversalMonthsMayAug() {
    opodoCancellationParserUniversalMonthsRange(tokens: [
        ("May.", 5),
        ("Jun.", 6),
        ("Jul.", 7),
        ("Aug.", 8),
    ])
}

@Test("OpodoCancellationDeadlineParser erkennt Monatsabkürzungen (Sep–Dec)")
func opodoCancellationParserUniversalMonthsSepDec() {
    opodoCancellationParserUniversalMonthsRange(tokens: [
        ("Sep.", 9),
        ("Oct.", 10),
        ("Nov.", 11),
        ("Dec.", 12),
    ])
}

private func opodoCancellationParserUniversalMonthsRange(tokens: [(String, Int)]) {
    for (token, expectedMonth) in tokens {
        let html = """
        <html><body>
          <div>Cancellation policy until 1 \(token) 2026 (until 22:00) - free cancellation</div>
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

