import Foundation
import Testing
import ReisenDomain
import ReisenProviders
@testable import ReisenBilligerMietwagen

enum BilligerMietwagenResearchFixture {
    static func json(named name: String) throws -> String {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("docs/fixtures/provider-research")
            .appendingPathComponent(name)
        return try String(contentsOf: url, encoding: .utf8)
    }
}

@Test("BilligerMietwagenBookingsParser mappt active car_rental zu .carRental Drafts")
func bmBookingsParsesActiveCarRentalDraft() throws {
    let json = try BilligerMietwagenResearchFixture.json(named: "bm_bookings_active_redacted.json")
    let catalog = try BilligerMietwagenBookingsParser.parse(from: json)

    #expect(catalog.bookings.count == 1)
    let draft = try #require(catalog.bookings.first)

    #expect(draft.provider == .billigerMietwagen)
    #expect(draft.bookingType == .carRental)
    #expect(draft.status == .confirmed)
    #expect(draft.title == "Berlin → München")
    #expect(draft.confirmationCode == "<REDACTED>")
    #expect(
        draft.externalUrl
            == BilligerMietwagenWebConstants.bookingPageURL(id: "<REDACTED-UUID>")
    )
    #expect(
        draft.cancellationUrl
            == BilligerMietwagenWebConstants.cancellationPageURL
    )
    #expect(draft.cancellationUrl != draft.externalUrl)
    #expect(draft.startAt == iso8601("2026-09-15T10:00:00+02:00"))
    #expect(draft.endAt == iso8601("2026-09-20T10:00:00+02:00"))
    #expect(draft.locationFrom == "Berlin")
    #expect(draft.locationTo == "München")
    #expect(draft.operatorName == "Thrifty")
    #expect(draft.rateDetails?.totalPriceAmount == 58.0)
    #expect(draft.rateDetails?.totalPriceCurrency == "EUR")
    #expect(draft.rateDetails?.roomCategory == "compact")
    #expect(draft.hotelOffsetSeconds == 2 * 3600)
}

@Test("BilligerMietwagenBookingsParser liest next-Page aus _pointers")
func bmBookingsParsePageReadsNextPointer() throws {
    let json = """
    {
      "total_count": 12,
      "_pointers": { "self": "0", "first": "0", "last": "1", "next": "1" },
      "items": [
        {
          "id": "page0",
          "type": "car_rental",
          "status": "confirmed",
          "reservation_id": "r0",
          "pick_up": { "city": "Berlin", "date": "2026-09-15T10:00:00+02:00" },
          "drop_off": { "city": "Berlin", "date": "2026-09-16T10:00:00+02:00" },
          "supplier": { "name": "Thrifty" }
        }
      ]
    }
    """
    let page0 = try BilligerMietwagenBookingsParser.parsePage(from: json, fetchedPage: 0)
    #expect(page0.bookings.count == 1)
    #expect(page0.nextPage == 1)

    let lastJSON = """
    {
      "_pointers": { "self": "1", "first": "0", "last": "1" },
      "items": []
    }
    """
    let page1 = try BilligerMietwagenBookingsParser.parsePage(from: lastJSON, fetchedPage: 1)
    #expect(page1.nextPage == nil)
}

@Test("BilligerMietwagenBookingsParser überspringt Einträge ohne Offset und error-Status")
func bmBookingsSkipsMissingOffsetAndError() throws {
    let json = """
    {
      "items": [
        {
          "id": "keep",
          "type": "car_rental",
          "status": "confirmed",
          "reservation_id": "keep-ref",
          "pick_up": { "city": "Berlin", "date": "2026-09-15T10:00:00+02:00" },
          "drop_off": { "city": "Berlin", "date": "2026-09-16T10:00:00+02:00" },
          "supplier": { "name": "Thrifty" }
        },
        {
          "id": "skip-offset",
          "type": "car_rental",
          "status": "confirmed",
          "reservation_id": "skip-ref",
          "pick_up": { "city": "Berlin", "date": "2026-09-15T10:00:00" },
          "drop_off": { "city": "Berlin", "date": "2026-09-16T10:00:00" },
          "supplier": { "name": "Thrifty" }
        },
        {
          "id": "skip-error",
          "type": "car_rental",
          "status": "error",
          "reservation_id": "err-ref",
          "pick_up": { "city": "Berlin", "date": "2026-09-15T10:00:00+02:00" },
          "drop_off": { "city": "Berlin", "date": "2026-09-16T10:00:00+02:00" },
          "supplier": { "name": "Thrifty" }
        }
      ]
    }
    """
    let catalog = try BilligerMietwagenBookingsParser.parse(from: json)
    #expect(catalog.bookings.map(\.confirmationCode) == ["keep-ref"])
}

@Test("BilligerMietwagenBookingDetailParser mappt Web-Detail ohne Deadline ohne Offset")
func bmDetailParsesEnrichmentWithoutNaiveDeadline() throws {
    let json = try BilligerMietwagenResearchFixture.json(named: "bm_booking_detail_web_redacted.json")
    let enrichment = try BilligerMietwagenBookingDetailParser.parse(from: json)

    #expect(enrichment.title == "Ford Focus STW")
    #expect(enrichment.locationFrom == "Berlin")
    #expect(enrichment.locationTo == "München")
    #expect(enrichment.operatorName == "Thrifty")
    #expect(enrichment.rateDetails?.roomCategory == "manual")
    #expect(enrichment.rateDetails?.totalPriceAmount == 58.0)
    // Fixture `canceled` → DraftAssembler verwirft Fristen; ohne Katalog-Offset kein cancelUntil-Instant.
    #expect(enrichment.deadlines.isEmpty)
    #expect(enrichment.guestHints?.contains(where: { $0.title == "Tankregelung" }) == true)
    // cancelUntil vorhanden → kein redundanter Stunden-GuestHint
    #expect(enrichment.guestHints?.contains(where: { $0.title == "Stornierung" }) != true)
    #expect(enrichment.guestHints?.contains(where: { $0.title == "Voucher" }) == true)
    #expect(enrichment.passengers?.count == 1)
    #expect(enrichment.passengers?.first?.givenName == "<REDACTED>")
}

@Test("BilligerMietwagenBookingDetailParser nutzt cancelUntil als Stornofrist")
func bmDetailDeadlineFromCancelUntil() throws {
    let json = """
    {
      "reservation": {
        "id": "762905790",
        "status": "confirmed",
        "cancelUntil": "2026-10-18T12:00:00"
      },
      "offer": {
        "model": "Opel Adam",
        "transmission": "manual",
        "supplier": "Dollar",
        "free_cancellation": true,
        "free_cancellation_hours": 24,
        "currency": "EUR",
        "price": 162.61,
        "fuel_policy": "full_full"
      },
      "rental": {
        "pickUp": {
          "address": { "city": "Berlin", "street": "BER", "country": "DE", "postalCode": "" },
          "datetime": "2026-10-19T12:00:00"
        },
        "dropOff": {
          "address": { "city": "Berlin", "street": "BER", "country": "DE", "postalCode": "" },
          "datetime": "2026-10-22T09:00:00"
        }
      },
      "driver": { "name": "<REDACTED>" },
      "files": {
        "voucher": { "url": "https://consumer-api.floyt.com/useraccount/v1/web/bookings/x/voucher.pdf" }
      }
    }
    """
    let catalogStart = iso8601("2026-10-19T12:00:00+02:00")
    let enrichment = try BilligerMietwagenBookingDetailParser.parse(
        from: json,
        catalogStartAt: catalogStart,
        hotelOffsetSeconds: 2 * 3600
    )
    #expect(enrichment.deadlines.count == 1)
    let deadline = try #require(enrichment.deadlines.first)
    #expect(deadline.isFreeCancellation == true)
    #expect(deadline.hotelOffsetSeconds == 2 * 3600)
    #expect(deadline.deadlineAt == iso8601("2026-10-18T12:00:00+02:00"))
    #expect(deadline.policyText == nil)
    // Portal: cancelUntil = „bis So, 18.10.2026, 12:00“; Stunden-Hint nicht zusätzlich
    #expect(enrichment.guestHints?.contains(where: { $0.title == "Stornierung" }) != true)
    // Anzeige-Ortszeit wie Portal
    let tz = TimeZone(secondsFromGMT: 2 * 3600)!
    let formatted = CancellationDeadlineFormatting.formatOrtszeit(
        deadline.deadlineAt,
        dateFormat: "d.M.yyyy HH:mm",
        timeZone: tz
    )
    #expect(formatted == "18.10.2026 12:00")
    // Semantik: genau 24h vor Katalog-Pickup
    #expect(catalogStart.timeIntervalSince(deadline.deadlineAt) == 24 * 3600)
}

@Test("BilligerMietwagen cancelUntil ohne free_cancellation ist nicht als Free markiert")
func bmCancelUntilWithoutFreeFlagIsNotFree() throws {
    let json = """
    {
      "reservation": { "id": "r1", "status": "confirmed", "cancel_until": "2026-10-18T12:00:00" },
      "offer": { "model": "X", "supplier": "Y", "free_cancellation": false, "currency": "EUR", "price": 1 },
      "rental": {
        "pickUp": { "address": { "city": "Berlin" }, "datetime": "2026-10-19T12:00:00" },
        "dropOff": { "address": { "city": "Berlin" }, "datetime": "2026-10-20T12:00:00" }
      }
    }
    """
    let enrichment = try BilligerMietwagenBookingDetailParser.parse(
        from: json,
        catalogStartAt: iso8601("2026-10-19T12:00:00+02:00"),
        hotelOffsetSeconds: 2 * 3600
    )
    let deadline = try #require(enrichment.deadlines.first)
    #expect(deadline.isFreeCancellation == false)
    #expect(deadline.policyText == "Stornierung bis zum angegebenen Zeitpunkt")
}

@Test("BilligerMietwagenBookingDetailParser Fallback Stornofrist aus Katalog-startAt")
func bmDetailDeadlineFromCatalogStart() throws {
    let json = """
    {
      "reservation": { "id": "r1", "status": "confirmed" },
      "offer": {
        "model": "Opel Adam",
        "transmission": "manual",
        "supplier": "Dollar",
        "free_cancellation": true,
        "free_cancellation_hours": 24,
        "currency": "EUR",
        "price": 162.61,
        "fuel_policy": "full_full"
      },
      "rental": {
        "pickUp": {
          "address": { "city": "Berlin", "street": "BER", "country": "DE", "postalCode": "" },
          "datetime": "2026-10-19T12:00:00"
        },
        "dropOff": {
          "address": { "city": "Berlin", "street": "BER", "country": "DE", "postalCode": "" },
          "datetime": "2026-10-22T09:00:00"
        }
      },
      "driver": { "name": "<REDACTED>" },
      "files": {
        "voucher": { "url": "https://consumer-api.floyt.com/useraccount/v1/web/bookings/x/voucher.pdf" }
      }
    }
    """
    let catalogStart = iso8601("2026-10-19T12:00:00+02:00")
    let enrichment = try BilligerMietwagenBookingDetailParser.parse(
        from: json,
        catalogStartAt: catalogStart,
        hotelOffsetSeconds: 2 * 3600
    )
    #expect(enrichment.deadlines.count == 1)
    let deadline = try #require(enrichment.deadlines.first)
    #expect(deadline.isFreeCancellation == true)
    #expect(deadline.deadlineAt == iso8601("2026-10-18T12:00:00+02:00"))
    #expect(deadline.hotelOffsetSeconds == 2 * 3600)
}

@Test("BilligerMietwagenTokenPair erkennt fehlenden access_token")
func bmSessionParserAnonymousHasNoToken() throws {
    let json = try BilligerMietwagenResearchFixture.json(named: "bm_session_anonymous_redacted.json")
    let session = try BilligerMietwagenTokenPair.parseSession(from: json)
    #expect(session.hasSessionTokens == false)
}

@Test("BilligerMietwagenTokenPair akzeptiert redigiertes Token-Shape")
func bmSessionParserOkShape() throws {
    let json = try BilligerMietwagenResearchFixture.json(named: "bm_session_ok_redacted.json")
    let session = try BilligerMietwagenTokenPair.parseSession(from: json)
    #expect(session.hasSessionTokens == true)
    #expect(session.accessToken?.contains("<REDACTED") == true)
}

@Test("BilligerMietwagenWebConstants Allowlist und bookingID")
func bmWebConstantsAllowlistAndBookingID() {
    #expect(BilligerMietwagenAuthConstants.loginPageURL.path.contains("/reservation/account/login"))
    #expect(BilligerMietwagenAuthConstants.whitelabel == "DE_billiger-mietwagen")
    #expect(BilligerMietwagenAuthConstants.loginAPIURL.path == "/auth/v1/login")
    #expect(BilligerMietwagenAuthConstants.refreshTokenURL.path == "/auth/v1/refresh-token")
    #expect(
        BilligerMietwagenWebConstants.bookingsAPIURL.absoluteString
            .contains("consumer-api.floyt.com/useraccount/v1/bookings")
    )
    #expect(
        BilligerMietwagenWebConstants.CatalogList.active.url(page: 0).absoluteString
            .contains("activity_status=active")
    )
    #expect(
        BilligerMietwagenWebConstants.CatalogList.inactive.url(page: 0).absoluteString
            .contains("activity_status=inactive")
    )
    let id = BilligerMietwagenWebConstants.bookingID(
        from: "https://www.billiger-mietwagen.de/reservation/account/bookings/abc-123"
    )
    #expect(id == "abc-123")
    #expect(
        BilligerMietwagenWebConstants.bookingID(from: "https://evil.example/reservation/account/bookings/abc")
            == nil
    )
}

@Test("BilligerMietwagenAccessToken liest user_id aus JWT username-Claim")
func bmAccessTokenReadsUsernameClaim() throws {
    // header.payload.sig — payload: {"username":"70321a5d-594f-40e2-93db-a8a69be5dd4b","sub":"other"}
    let payloadJSON = #"{"username":"70321a5d-594f-40e2-93db-a8a69be5dd4b","sub":"other"}"#
    let payload = Data(payloadJSON.utf8).base64EncodedString()
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
    let jwt = "hdr.\(payload).sig"
    #expect(BilligerMietwagenAccessToken.userID(fromAccessToken: jwt) == "70321a5d-594f-40e2-93db-a8a69be5dd4b")
}

@Test("BilligerMietwagenAccessToken ohne username-Claim liefert nil")
func bmAccessTokenMissingUsernameClaimReturnsNil() {
    let payloadJSON = #"{"sub":"70321a5d-594f-40e2-93db-a8a69be5dd4b"}"#
    let payload = Data(payloadJSON.utf8).base64EncodedString()
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
    let jwt = "hdr.\(payload).sig"
    #expect(BilligerMietwagenAccessToken.userID(fromAccessToken: jwt) == nil)
}

@Test("BilligerMietwagenTokenPair.parseRefresh liest access_token")
func bmRefreshParserReadsAccessToken() throws {
    let json = #"{"access_token":"<REDACTED_ACCESS>","refresh_token":"<REDACTED_REFRESH>","id_token":"<REDACTED_ID>"}"#
    let payload = try BilligerMietwagenTokenPair.parseRefresh(from: json)
    #expect(payload.accessToken == "<REDACTED_ACCESS>")
    #expect(payload.refreshToken == "<REDACTED_REFRESH>")
    let tokens = try payload.requiringRefreshedTokens(reusingRefresh: "<REDACTED_PREVIOUS>")
    #expect(tokens.access == "<REDACTED_ACCESS>")
    #expect(tokens.refresh == "<REDACTED_REFRESH>")
}

@Test("Refresh ohne refresh_token in der Antwort behält den verwendeten Refresh")
func bmRefreshReusesPreviousRefreshWhenResponseOmitsIt() throws {
    let payload = try BilligerMietwagenTokenPair.parseRefresh(
        from: #"{"access_token":"<REDACTED_ACCESS>","id_token":"<REDACTED_ID>"}"#
    )
    let tokens = try payload.requiringRefreshedTokens(reusingRefresh: "<REDACTED_PREVIOUS>")
    #expect(tokens.access == "<REDACTED_ACCESS>")
    #expect(tokens.refresh == "<REDACTED_PREVIOUS>")
}

@Test("Refresh ohne access_token bleibt Fehler")
func bmRefreshWithoutAccessTokenFails() throws {
    let payload = try BilligerMietwagenTokenPair.parseRefresh(from: #"{"id_token":"<REDACTED_ID>"}"#)
    #expect(throws: BilligerMietwagenProviderError.tokenRefreshFailed) {
        try payload.requiringRefreshedTokens(reusingRefresh: "<REDACTED_PREVIOUS>")
    }
}

@Test("BilligerMietwagenBookingsParser überspringt Einträge ohne type car_rental")
func bmBookingsSkipsNonCarRentalType() throws {
    let json = """
    {
      "items": [
        {
          "id": "keep",
          "type": "car_rental",
          "status": "confirmed",
          "reservation_id": "keep-ref",
          "pick_up": { "city": "Berlin", "date": "2026-09-15T10:00:00+02:00" },
          "drop_off": { "city": "Berlin", "date": "2026-09-16T10:00:00+02:00" },
          "supplier": { "name": "Thrifty" }
        },
        {
          "id": "skip-nil-type",
          "status": "confirmed",
          "reservation_id": "nil-ref",
          "pick_up": { "city": "Berlin", "date": "2026-09-15T10:00:00+02:00" },
          "drop_off": { "city": "Berlin", "date": "2026-09-16T10:00:00+02:00" },
          "supplier": { "name": "Thrifty" }
        },
        {
          "id": "skip-other",
          "type": "hotel",
          "status": "confirmed",
          "reservation_id": "hotel-ref",
          "pick_up": { "city": "Berlin", "date": "2026-09-15T10:00:00+02:00" },
          "drop_off": { "city": "Berlin", "date": "2026-09-16T10:00:00+02:00" },
          "supplier": { "name": "Thrifty" }
        }
      ]
    }
    """
    let catalog = try BilligerMietwagenBookingsParser.parse(from: json)
    #expect(catalog.bookings.map(\.confirmationCode) == ["keep-ref"])
}

@Test("#59 Cookie-Session: user_id aus Cognito-username, beide Refresh-Tokens, kein sub")
func bmCookieSessionRefreshUsesCognitoUsernameNotSub() throws {
    // session.php-access_token ohne Claim `username` (heute Throw A).
    // user_id liegt in `cognito:username`; `sub` ist eine andere ID.
    let userID = "a18c0e2f-4b6d-4e1a-9c3f-7d2a1b0e5f44"
    let sub = "other-sub"
    let accessJWT = bmJWT(
        payloadJSON: #"{"cognito:username":"\#(userID)","sub":"\#(sub)","token_use":"access"}"#
    )

    let session = try BilligerMietwagenTokenPair.parseSession(
        from: """
        {"access_token":"\(accessJWT)","refresh_token":"<REDACTED_REFRESH>"}
        """
    )
    let sessionTokens = try session.requiringSessionTokens()

    let parsedUserID = try #require(
        BilligerMietwagenAccessToken.userID(fromAccessToken: sessionTokens.access)
    )
    #expect(parsedUserID == userID)
    #expect(parsedUserID != sub)

    // Refresh-2xx mit beiden Tokens: persistierbares Paar (Catalog als Nächstes).
    let refreshed = try BilligerMietwagenTokenPair.parseRefresh(
        from: #"{"access_token":"<REDACTED_NEW_ACCESS>","refresh_token":"<REDACTED_NEW_REFRESH>"}"#
    )
    let tokens = try refreshed.requiringRefreshedTokens(reusingRefresh: sessionTokens.refresh)
    #expect(tokens.access == "<REDACTED_NEW_ACCESS>")
    #expect(tokens.refresh == "<REDACTED_NEW_REFRESH>")

    // Nur-sub: kein stiller Fallback.
    let onlySub = bmJWT(payloadJSON: #"{"sub":"\#(sub)"}"#)
    #expect(BilligerMietwagenAccessToken.userID(fromAccessToken: onlySub) == nil)
}

/// Test-JWT `header.payload.sig`; Payload ist JSON, Signatur egal.
private func bmJWT(payloadJSON: String) -> String {
    let payload = Data(payloadJSON.utf8).base64EncodedString()
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
    return "hdr.\(payload).sig"
}

private func iso8601(_ raw: String) -> Date {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.date(from: raw)!
}
