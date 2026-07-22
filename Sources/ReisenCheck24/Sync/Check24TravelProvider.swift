import Foundation
import WebKit
import ReisenDomain
import ReisenProviders

public enum Check24ProviderError: LocalizedError, Sendable {
    case sessionNotEstablished
    case activitiesFetchFailed(String)
    case noBookingsFound
    case snapshotFailed
    case navigationFailed
    case invalidSessionType

    public var errorDescription: String? {
        switch self {
        case .sessionNotEstablished:
            return "Es besteht noch keine Check24 Session. Bitte zunächst anmelden."
        case .activitiesFetchFailed(let detail):
            return "Activities-API konnte nicht geladen werden: \(detail)"
        case .noBookingsFound:
            return "Keine Buchungen gefunden."
        case .snapshotFailed:
            return "Snapshot konnte nicht erstellt werden."
        case .navigationFailed:
            return "Navigation in der Check24-Webansicht ist fehlgeschlagen."
        case .invalidSessionType:
            return "Ungültige Provider-Session für Check24."
        }
    }
}


/// WKWebView-backed session for Check24.
@MainActor
public final class Check24WebSession: ProviderSession {
    public let webView: WKWebView

    public init(webView: WKWebView) {
        self.webView = webView
    }
}

@MainActor
public final class Check24TravelProvider: TravelProvider, TravelProviderLoginConfiguration {
    public let id = ProviderID.check24
    public let displayName = "Check24"

    public var loginURL: URL { URL(string: "https://kundenbereich.check24.de/user/login.html")! }
    public var keychainServerHost: String { "check24.de" }

    public var onProgress: (@MainActor (String) -> Void)?

    public init() {}

    public func fetchCatalog(session: any ProviderSession) async throws -> ProviderCatalog {
        let webView = try webView(from: session)
        guard webView.url != nil else { throw Check24ProviderError.sessionNotEstablished }

        let activity = try await fetchActivity(using: webView)
        guard !activity.bookings.isEmpty else { return ProviderCatalog(bookings: []) }

        onProgress?("Prüfe Stornofristen…")

        var deadlinesByBookingURL: [String: [ParsedCancellationDeadline]] = [:]
        var hotelStayByBookingURL: [String: HotelCheckInOut] = [:]
        var bookingDetailsByBookingKey: [String: ParsedBookingDetails] = [:]

        // Multi-Room/Basket: Hotels werden zu einer Buchung pro `basketId` gemerged.
        var basketsByBasketId: [String: HotelBasketParser.ParsedHotelBasket] = [:]
        var bookingUuidToBasketId: [String: String] = [:]
        var canonicalBookingUuidByBasketId: [String: String] = [:]
        var deadlinesByBasketId: [String: [ParsedCancellationDeadline]] = [:]
        var hotelStayByBasketId: [String: HotelCheckInOut] = [:]
        var bookingDetailsByBasketId: [String: ParsedBookingDetails] = [:]

        var parsedBookingByBookingUuid: [String: ParsedBooking] = [:]

        try await maybeApplyInitialPolicySnapshot(from: webView, into: &deadlinesByBookingURL)

        let hotelBookingsWithURL = bookingsWithURL(for: .hotel, in: activity)
        try await enrichHotelBookings(
            hotelBookingsWithURL: hotelBookingsWithURL,
            webView: webView,
            deadlinesByBookingURL: &deadlinesByBookingURL,
            hotelStayByBookingURL: &hotelStayByBookingURL,
            bookingDetailsByBookingKey: &bookingDetailsByBookingKey,
            basketsByBasketId: &basketsByBasketId,
            bookingUuidToBasketId: &bookingUuidToBasketId,
            canonicalBookingUuidByBasketId: &canonicalBookingUuidByBasketId,
            deadlinesByBasketId: &deadlinesByBasketId,
            hotelStayByBasketId: &hotelStayByBasketId,
            bookingDetailsByBasketId: &bookingDetailsByBasketId,
            parsedBookingByBookingUuid: &parsedBookingByBookingUuid
        )

        let nonHotelBookingsWithURL = bookingsWithURL(for: .nonHotel, in: activity)
        try await enrichNonHotelBookings(
            nonHotelBookingsWithURL: nonHotelBookingsWithURL,
            webView: webView,
            bookingDetailsByBookingKey: &bookingDetailsByBookingKey
        )

        var draftByExternalUrl = makeBasketDrafts(
            basketsByBasketId: basketsByBasketId,
            canonicalBookingUuidByBasketId: canonicalBookingUuidByBasketId,
            parsedBookingByBookingUuid: parsedBookingByBookingUuid,
            deadlinesByBasketId: deadlinesByBasketId,
            deadlinesByBookingURL: deadlinesByBookingURL,
            hotelStayByBasketId: hotelStayByBasketId,
            hotelStayByBookingURL: hotelStayByBookingURL,
            bookingDetailsByBasketId: bookingDetailsByBasketId,
            bookingDetailsByBookingKey: bookingDetailsByBookingKey
        )

        addNonBasketDrafts(
            activity: activity,
            bookingUuidToBasketId: bookingUuidToBasketId,
            deadlinesByBookingURL: deadlinesByBookingURL,
            hotelStayByBookingURL: hotelStayByBookingURL,
            bookingDetailsByBookingKey: bookingDetailsByBookingKey,
            draftByExternalUrl: &draftByExternalUrl
        )

        let sorted = Array(draftByExternalUrl.values).sorted { $0.startAt < $1.startAt }
        return ProviderCatalog(bookings: sorted)
    }

    private enum BookingURLGroup {
        case hotel
        case nonHotel
    }

    private func fetchActivity(using webView: WKWebView) async throws -> ParsedActivity {
        onProgress?("Lade Aktivitäten (API)…")
        do {
            let activitiesJSON = try await fetchActivitiesJSON(using: webView)
            return try ActivityListParser().parseActivityListHTML(activitiesJSON)
        } catch {
            onProgress?("Activities-API fehlgeschlagen, nutze HTML-Snapshot…")
            let currentHTML = try await snapshotHTML(from: webView)
            return try ActivityListParser().parseActivityListHTML(currentHTML.html)
        }
    }

    private func maybeApplyInitialPolicySnapshot(
        from webView: WKWebView,
        into deadlinesByBookingURL: inout [String: [ParsedCancellationDeadline]]
    ) async throws {
        if let currentHTML = try? await snapshotHTML(from: webView) {
            let initialPolicy = CancellationPolicyParser().parseCancellationPolicy(from: currentHTML.html)
            if !initialPolicy.deadlines.isEmpty {
                deadlinesByBookingURL[currentHTML.url.absoluteString] = initialPolicy.deadlines
            }
        }
    }

    private func bookingsWithURL(
        for group: BookingURLGroup,
        in activity: ParsedActivity
    ) -> [(ParsedBooking, URL)] {
        switch group {
        case .hotel:
            return activity.bookings.compactMap { booking -> (ParsedBooking, URL)? in
                guard booking.type == .hotel else { return nil }
                guard let urlString = booking.externalUrl, let url = URL(string: urlString) else { return nil }
                guard isHotelBookingDetailURL(url) else { return nil }
                return (booking, url)
            }
        case .nonHotel:
            return activity.bookings.compactMap { booking -> (ParsedBooking, URL)? in
                guard booking.type == .flight || booking.type == .ferry else { return nil }
                guard let urlString = booking.externalUrl, let url = URL(string: urlString) else { return nil }
                guard isNonHotelBookingDetailURL(url) else { return nil }
                return (booking, url)
            }
        }
    }

    private func enrichHotelBookings(
        hotelBookingsWithURL: [(ParsedBooking, URL)],
        webView: WKWebView,
        deadlinesByBookingURL: inout [String: [ParsedCancellationDeadline]],
        hotelStayByBookingURL: inout [String: HotelCheckInOut],
        bookingDetailsByBookingKey: inout [String: ParsedBookingDetails],
        basketsByBasketId: inout [String: HotelBasketParser.ParsedHotelBasket],
        bookingUuidToBasketId: inout [String: String],
        canonicalBookingUuidByBasketId: inout [String: String],
        deadlinesByBasketId: inout [String: [ParsedCancellationDeadline]],
        hotelStayByBasketId: inout [String: HotelCheckInOut],
        bookingDetailsByBasketId: inout [String: ParsedBookingDetails],
        parsedBookingByBookingUuid: inout [String: ParsedBooking]
    ) async throws {
        for (index, item) in hotelBookingsWithURL.enumerated() {
            let (parsedBooking, bookingURL) = item
            let bookingURLString = parsedBooking.externalUrl ?? bookingURL.absoluteString

            if let externalUrl = parsedBooking.externalUrl {
                let bookingUuid = String(externalUrl.split(separator: "/").last ?? "")
                parsedBookingByBookingUuid[bookingUuid] = parsedBooking

                if let basketId = bookingUuidToBasketId[bookingUuid],
                   basketsByBasketId[basketId] != nil {
                    continue
                }
            }

            if let key = identityKey(for: parsedBooking),
               bookingDetailsByBookingKey[key] != nil {
                continue
            }

            onProgress?("Stornofrist \(index + 1)/\(hotelBookingsWithURL.count)…")
            try await enrichHotelDetail(
                webView: webView,
                parsedBooking: parsedBooking,
                bookingURL: bookingURL,
                bookingURLString: bookingURLString,
                deadlinesByBookingURL: &deadlinesByBookingURL,
                hotelStayByBookingURL: &hotelStayByBookingURL,
                bookingDetailsByBookingKey: &bookingDetailsByBookingKey,

                basketsByBasketId: &basketsByBasketId,
                bookingUuidToBasketId: &bookingUuidToBasketId,
                canonicalBookingUuidByBasketId: &canonicalBookingUuidByBasketId,
                deadlinesByBasketId: &deadlinesByBasketId,
                hotelStayByBasketId: &hotelStayByBasketId,
                bookingDetailsByBasketId: &bookingDetailsByBasketId
            )
        }
    }

    private func enrichNonHotelBookings(
        nonHotelBookingsWithURL: [(ParsedBooking, URL)],
        webView: WKWebView,
        bookingDetailsByBookingKey: inout [String: ParsedBookingDetails]
    ) async throws {
        for (index, item) in nonHotelBookingsWithURL.enumerated() {
            let (parsedBooking, bookingURL) = item

            if let key = identityKey(for: parsedBooking),
               bookingDetailsByBookingKey[key] != nil {
                continue
            }

            onProgress?("Details \(index + 1)/\(nonHotelBookingsWithURL.count)…")
            try await enrichNonHotelDetail(
                webView: webView,
                parsedBooking: parsedBooking,
                bookingURL: bookingURL,
                bookingDetailsByBookingKey: &bookingDetailsByBookingKey
            )
        }
    }

    private func makeBasketDrafts(
        basketsByBasketId: [String: HotelBasketParser.ParsedHotelBasket],
        canonicalBookingUuidByBasketId: [String: String],
        parsedBookingByBookingUuid: [String: ParsedBooking],
        deadlinesByBasketId: [String: [ParsedCancellationDeadline]],
        deadlinesByBookingURL: [String: [ParsedCancellationDeadline]],
        hotelStayByBasketId: [String: HotelCheckInOut],
        hotelStayByBookingURL: [String: HotelCheckInOut],
        bookingDetailsByBasketId: [String: ParsedBookingDetails],
        bookingDetailsByBookingKey: [String: ParsedBookingDetails]
    ) -> [String: ProviderBookingDraft] {
        var draftByExternalUrl: [String: ProviderBookingDraft] = [:]

        for (basketId, basket) in basketsByBasketId {
            let canonicalUUID = canonicalBookingUuidByBasketId[basketId]
                ?? basket.items.map(\.bookingUuid).sorted().first

            guard let canonicalUUID,
                  let canonicalBooking = parsedBookingByBookingUuid[canonicalUUID],
                  let canonicalExternalUrl = canonicalBooking.externalUrl else {
                continue
            }

            let deadlinesParsed = deadlinesByBasketId[basketId]
                ?? deadlinesByBookingURL[canonicalExternalUrl]
                ?? []
            let stay = hotelStayByBasketId[basketId] ?? hotelStayByBookingURL[canonicalExternalUrl]

            let enrichedDetails = bookingDetailsByBasketId[basketId]
                ?? identityKey(for: canonicalBooking)
                    .flatMap { bookingDetailsByBookingKey[$0] }
            let mergedDetails = mergeBookingDetails(primary: enrichedDetails, secondary: canonicalBooking.details)
            let rateDetails = mapBasketRateDetails(basket: basket, details: mergedDetails)

            let deadlines = deadlinesParsed.map(mapDeadline)
            let basketConfirmation = basket.items
                .compactMap(\.bookingNumber)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: ", ")

            let draft = ProviderBookingDraft(
                provider: .check24,
                bookingType: canonicalBooking.type,
                title: canonicalBooking.title,
                confirmationCode: basketConfirmation.isEmpty ? canonicalBooking.confirmationCode : basketConfirmation,
                externalUrl: canonicalExternalUrl,
                startAt: canonicalBooking.startAt,
                endAt: canonicalBooking.endAt,
                locationFrom: canonicalBooking.locationFrom,
                locationTo: canonicalBooking.locationTo,
                locationFromAddress: canonicalBooking.locationFromAddress,
                locationToAddress: canonicalBooking.locationToAddress,
                status: canonicalBooking.status,
                deadlines: deadlines,
                rateDetails: rateDetails,
                hotelOffsetSeconds: deadlines.compactMap(\.hotelOffsetSeconds).first,
                hotelCheckInMinutes: stay?.checkInMinutes,
                hotelCheckOutMinutes: stay?.checkOutMinutes,
                rawPayloadFingerprint: mergedDetails?.rawDetailsFingerprint
            )

            draftByExternalUrl[canonicalExternalUrl] = draft
        }

        return draftByExternalUrl
    }

    private func addNonBasketDrafts(
        activity: ParsedActivity,
        bookingUuidToBasketId: [String: String],
        deadlinesByBookingURL: [String: [ParsedCancellationDeadline]],
        hotelStayByBookingURL: [String: HotelCheckInOut],
        bookingDetailsByBookingKey: [String: ParsedBookingDetails],
        draftByExternalUrl: inout [String: ProviderBookingDraft]
    ) {
        for parsed in activity.bookings {
            if parsed.type == .hotel, let externalUrl = parsed.externalUrl {
                let bookingUuid = String(externalUrl.split(separator: "/").last ?? "")
                if bookingUuidToBasketId[bookingUuid] != nil {
                    continue
                }
            }

            guard parsed.type == .flight || parsed.type == .ferry || parsed.type == .hotel else { continue }

            let draft = mapDraft(
                parsed,
                allBookings: activity.bookings,
                deadlinesByBookingURL: deadlinesByBookingURL,
                hotelStayByBookingURL: hotelStayByBookingURL,
                bookingDetailsByBookingKey: bookingDetailsByBookingKey
            )
            guard let key = draft.externalUrl else { continue }
            draftByExternalUrl[key] = draft
        }
    }

    public func enrichBooking(
        session: any ProviderSession,
        ref: ProviderBookingRef
    ) async throws -> ProviderBookingEnrichment {
        let webView = try webView(from: session)
        guard let url = URL(string: ref.externalUrl) else {
            throw Check24ProviderError.navigationFailed
        }
        try await load(url: url, in: webView)
        await dismissBookingChooserIfNeeded(
            in: webView,
            needles: [ref.externalUrl, url.lastPathComponent]
        )
        let snapshot = try await snapshotHTML(from: webView)
        let policy = CancellationPolicyParser().parseCancellationPolicy(from: snapshot.html)
        let details = BookingDetailsParser().parse(from: snapshot.html, bookingType: ref.bookingType)
        let stay = HotelCheckInOutParser().parse(from: snapshot.html)
        var passengers: [BookingPassenger]? = nil
        if ref.bookingType == .flight {
            let parser = Check24FlightPassengersAndLuggageParser()
            let guestNames = parser.guestNames(from: snapshot.html)
            if !guestNames.isEmpty, let statusURL = check24StatusURL(from: ref.externalUrl) {
                do {
                    let statusText = try await webView.fetchAuthenticatedText(
                        url: statusURL,
                        accept: "application/json, text/plain, */*",
                        referer: ref.externalUrl
                    )
                    let baggage = try parser.baggageAllowances(from: statusText)
                    let built = parser.buildPassengers(
                        guestNames: guestNames,
                        baggageAllowances: baggage,
                        travellerType: .adult
                    )
                    passengers = built.isEmpty ? nil : built
                } catch {
                    passengers = nil
                }
            }
        }

        // Mehrzimmer-Detailseite: „basketDetails.basketPrice“ ist der Bestell-Gesamtpreis.
        // Deshalb parsen wir den Basket und übernehmen Preis + `roomItems` konsistent.
        var rate: BookingRateDetails
        if let basket = HotelBasketParser.parse(from: snapshot.html),
           let basketRate = mapBasketRateDetails(basket: basket, details: details) {
            rate = basketRate
        } else {
            rate = mapRateDetails(details)
        }

        return ProviderBookingEnrichment(
            deadlines: policy.deadlines.map(mapDeadline),
            rateDetails: rate,
            passengers: passengers,
            hotelOffsetSeconds: policy.deadlines.compactMap(\.hotelOffsetSeconds).first,
            hotelCheckInMinutes: stay.checkInMinutes,
            hotelCheckOutMinutes: stay.checkOutMinutes
        )
    }

    private func check24StatusURL(from externalUrl: String) -> URL? {
        guard let url = URL(string: externalUrl) else { return nil }
        // Expected path:
        // /kundenbereich/<filekey>/<surname>
        guard let idx = url.pathComponents.firstIndex(of: "kundenbereich"),
              url.pathComponents.count > idx + 2
        else { return nil }

        let fileKey = url.pathComponents[idx + 1]
        let surname = url.pathComponents[idx + 2]

        let surnameEncoded = surname.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? surname

        return URL(string: "https://pbe.flug.check24.de/api/status/\(fileKey):\(surnameEncoded)")
    }

    private func webView(from session: any ProviderSession) throws -> WKWebView {
        guard let check24 = session as? Check24WebSession else {
            throw Check24ProviderError.invalidSessionType
        }
        return check24.webView
    }

    private func enrichHotelDetail(
        webView: WKWebView,
        parsedBooking: ParsedBooking,
        bookingURL: URL,
        bookingURLString: String,
        deadlinesByBookingURL: inout [String: [ParsedCancellationDeadline]],
        hotelStayByBookingURL: inout [String: HotelCheckInOut],
        bookingDetailsByBookingKey: inout [String: ParsedBookingDetails],

        basketsByBasketId: inout [String: HotelBasketParser.ParsedHotelBasket],
        bookingUuidToBasketId: inout [String: String],
        canonicalBookingUuidByBasketId: inout [String: String],
        deadlinesByBasketId: inout [String: [ParsedCancellationDeadline]],
        hotelStayByBasketId: inout [String: HotelCheckInOut],
        bookingDetailsByBasketId: inout [String: ParsedBookingDetails]
    ) async throws {
        let alreadyThere = webView.url?.absoluteString == bookingURL.absoluteString
            || (webView.url?.path == bookingURL.path && webView.url?.host == bookingURL.host)
        if !alreadyThere {
            try await load(url: bookingURL, in: webView)
        }

        await dismissBookingChooserIfNeeded(in: webView, for: parsedBooking)
        _ = await waitForHotelDetailReady(in: webView)

        let detailSnapshot = try await snapshotHTML(from: webView)
        let html = detailSnapshot.html

        let parsedBasket = HotelBasketParser.parse(from: html)
        let basketId = parsedBasket?.basketId

        let policy = CancellationPolicyParser().parseCancellationPolicy(from: html)
        let parsedDetails = BookingDetailsParser().parse(from: html, bookingType: parsedBooking.type)
        let stay = HotelCheckInOutParser().parse(from: html)

        if let basketId {
            persistBasketState(
                basketId: basketId,
                parsedBasket: parsedBasket,
                bookingURLString: bookingURLString,
                basketsByBasketId: &basketsByBasketId,
                bookingUuidToBasketId: &bookingUuidToBasketId,
                canonicalBookingUuidByBasketId: &canonicalBookingUuidByBasketId
            )

            persistBasketDetails(
                basketId: basketId,
                parsedDetails: parsedDetails,
                policyDeadlines: policy.deadlines,
                stay: stay,
                bookingURLString: bookingURLString,
                bookingDetailsByBasketId: &bookingDetailsByBasketId,
                deadlinesByBasketId: &deadlinesByBasketId,
                deadlinesByBookingURL: &deadlinesByBookingURL,
                hotelStayByBasketId: &hotelStayByBasketId,
                hotelStayByBookingURL: &hotelStayByBookingURL
            )
        } else {
            persistNonBasketDetails(
                parsedBooking: parsedBooking,
                parsedDetails: parsedDetails,
                stay: stay,
                policyDeadlines: policy.deadlines,
                bookingURLString: bookingURLString,
                bookingDetailsByBookingKey: &bookingDetailsByBookingKey,
                hotelStayByBookingURL: &hotelStayByBookingURL,
                deadlinesByBookingURL: &deadlinesByBookingURL
            )
        }
    }

    private func waitForHotelDetailReady(in webView: WKWebView) async -> Bool {
        await webView.waitForJavaScriptCondition(
            """
            document.documentElement.outerHTML.includes('cancelationLabelFee') ||
            document.documentElement.outerHTML.includes('cancelationLabelTime') ||
            document.documentElement.outerHTML.includes('cancelableUntilHotel') ||
            document.documentElement.outerHTML.includes('cancelableUntilUtc') ||
            document.documentElement.outerHTML.includes('basketContainer') ||
            document.documentElement.outerHTML.includes('a12524652-total') ||
            document.documentElement.outerHTML.includes('effektiver Preis') ||
            document.documentElement.outerHTML.includes('Gesamtpreis') ||
            document.documentElement.outerHTML.includes('€')
            """,
            timeoutSeconds: 12
        )
    }

    private func persistBasketState(
        basketId: String,
        parsedBasket: HotelBasketParser.ParsedHotelBasket?,
        bookingURLString: String,
        basketsByBasketId: inout [String: HotelBasketParser.ParsedHotelBasket],
        bookingUuidToBasketId: inout [String: String],
        canonicalBookingUuidByBasketId: inout [String: String]
    ) {
        if basketsByBasketId[basketId] == nil, let parsedBasket {
            basketsByBasketId[basketId] = parsedBasket
        }
        if let basket = basketsByBasketId[basketId] {
            for item in basket.items {
                bookingUuidToBasketId[item.bookingUuid] = basketId
            }
        }

        // Robust: kanonische Activity-UUID anhand der gerade geladenen Detail-URL.
        // So bleibt der Merge korrekt, auch wenn `basket.items[].bookingUuid`
        // nicht 1:1 mit Activity-`foreignId`/Zimmer-UUIDs übereinstimmt.
        let currentBookingUuid = bookingURLString.split(separator: "/").last.flatMap(String.init)
        if let currentBookingUuid, canonicalBookingUuidByBasketId[basketId] == nil {
            canonicalBookingUuidByBasketId[basketId] = currentBookingUuid
        }
    }

    private func persistBasketDetails(
        basketId: String,
        parsedDetails: ParsedBookingDetails,
        policyDeadlines: [ParsedCancellationDeadline],
        stay: HotelCheckInOut,
        bookingURLString: String,
        bookingDetailsByBasketId: inout [String: ParsedBookingDetails],
        deadlinesByBasketId: inout [String: [ParsedCancellationDeadline]],
        deadlinesByBookingURL: inout [String: [ParsedCancellationDeadline]],
        hotelStayByBasketId: inout [String: HotelCheckInOut],
        hotelStayByBookingURL: inout [String: HotelCheckInOut]
    ) {
        if bookingDetailsByBasketId[basketId] == nil {
            bookingDetailsByBasketId[basketId] = parsedDetails
        }

        if !policyDeadlines.isEmpty {
            deadlinesByBasketId[basketId] = policyDeadlines
            deadlinesByBookingURL[bookingURLString] = policyDeadlines
        }

        if stay.checkInMinutes != nil || stay.checkOutMinutes != nil {
            hotelStayByBasketId[basketId] = stay
            hotelStayByBookingURL[bookingURLString] = stay
        }
    }

    private func persistNonBasketDetails(
        parsedBooking: ParsedBooking,
        parsedDetails: ParsedBookingDetails,
        stay: HotelCheckInOut,
        policyDeadlines: [ParsedCancellationDeadline],
        bookingURLString: String,
        bookingDetailsByBookingKey: inout [String: ParsedBookingDetails],
        hotelStayByBookingURL: inout [String: HotelCheckInOut],
        deadlinesByBookingURL: inout [String: [ParsedCancellationDeadline]]
    ) {
        if let key = identityKey(for: parsedBooking) {
            bookingDetailsByBookingKey[key] = parsedDetails
        }

        if stay.checkInMinutes != nil || stay.checkOutMinutes != nil {
            hotelStayByBookingURL[bookingURLString] = stay
        }

        if !policyDeadlines.isEmpty {
            deadlinesByBookingURL[bookingURLString] = policyDeadlines
        }
    }

    private func enrichNonHotelDetail(
        webView: WKWebView,
        parsedBooking: ParsedBooking,
        bookingURL: URL,
        bookingDetailsByBookingKey: inout [String: ParsedBookingDetails]
    ) async throws {
        let alreadyThere = webView.url?.absoluteString == bookingURL.absoluteString
            || (webView.url?.path == bookingURL.path && webView.url?.host == bookingURL.host)
        if !alreadyThere {
            try await load(url: bookingURL, in: webView)
        }

        let hasDetailsData = await webView.waitForJavaScriptCondition(
            """
            document.documentElement.outerHTML.includes('thirdViewData') &&
            document.documentElement.outerHTML.includes('bookingInfo')
            """,
            timeoutSeconds: 8
        )
        guard hasDetailsData else { return }

        let detailSnapshot = try await snapshotHTML(from: webView)
        let parsedDetails = BookingDetailsParser().parse(
            from: detailSnapshot.html,
            bookingType: parsedBooking.type
        )
        if let key = identityKey(for: parsedBooking) {
            bookingDetailsByBookingKey[key] = parsedDetails
        }
    }

    private func mapDraft(
        _ parsed: ParsedBooking,
        allBookings: [ParsedBooking],
        deadlinesByBookingURL: [String: [ParsedCancellationDeadline]],
        hotelStayByBookingURL: [String: HotelCheckInOut],
        bookingDetailsByBookingKey: [String: ParsedBookingDetails]
    ) -> ProviderBookingDraft {
        let url = parsed.externalUrl
        let deadlines = (url.flatMap { deadlinesByBookingURL[$0] } ?? []).map(mapDeadline)
        let stay = url.flatMap { hotelStayByBookingURL[$0] }
        let enrichedDetails = identityKey(for: parsed).flatMap { bookingDetailsByBookingKey[$0] }
        let details = mergeBookingDetails(primary: enrichedDetails, secondary: parsed.details)
        let rateDetails = HotelBookingPriceResolver.resolve(
            booking: parsed,
            siblings: allBookings,
            detail: details
        )

        return ProviderBookingDraft(
            provider: .check24,
            bookingType: parsed.type,
            title: parsed.title,
            confirmationCode: parsed.confirmationCode,
            externalUrl: parsed.externalUrl,
            startAt: parsed.startAt,
            endAt: parsed.endAt,
            locationFrom: parsed.locationFrom,
            locationTo: parsed.locationTo,
            locationFromAddress: parsed.locationFromAddress,
            locationToAddress: parsed.locationToAddress,
            status: parsed.status,
            deadlines: deadlines,
            rateDetails: rateDetails,
            hotelOffsetSeconds: deadlines.compactMap(\.hotelOffsetSeconds).first,
            hotelCheckInMinutes: stay?.checkInMinutes,
            hotelCheckOutMinutes: stay?.checkOutMinutes,
            rawPayloadFingerprint: details?.rawDetailsFingerprint
        )
    }

    private func mergeBookingDetails(
        primary: ParsedBookingDetails?,
        secondary: ParsedBookingDetails?
    ) -> ParsedBookingDetails? {
        switch (primary, secondary) {
        case let (p?, s?):
            return ParsedBookingDetails(
                rawDetailsFingerprint: p.rawDetailsFingerprint,
                totalPriceAmount: p.totalPriceAmount ?? s.totalPriceAmount,
                totalPriceCurrency: p.totalPriceCurrency ?? s.totalPriceCurrency,
                roomCategory: p.roomCategory ?? s.roomCategory,
                boardTypeRaw: p.boardTypeRaw ?? s.boardTypeRaw,
                includedBreakfast: p.includedBreakfast ?? s.includedBreakfast,
                guestCount: p.guestCount ?? s.guestCount,
                roomCount: p.roomCount ?? s.roomCount,
                airline: p.airline ?? s.airline,
                passengerCount: p.passengerCount ?? s.passengerCount,
                baggageInfoRaw: p.baggageInfoRaw ?? s.baggageInfoRaw
            )
        case let (p?, nil):
            return p
        case let (nil, s?):
            return s
        case (nil, nil):
            return nil
        }
    }

    private func mapDeadline(_ parsed: ParsedCancellationDeadline) -> CancellationDeadline {
        CancellationDeadline(
            deadlineAt: parsed.deadlineAt,
            policyText: parsed.policyText,
            isStrict: parsed.isStrict,
            isFreeCancellation: parsed.isFreeCancellation,
            hotelOffsetSeconds: parsed.hotelOffsetSeconds,
            cancellationFeeAmount: parsed.cancellationFeeAmount
        )
    }

    private func mapRateDetails(_ parsed: ParsedBookingDetails) -> BookingRateDetails {
        BookingRateDetails(
            rawDetailsFingerprint: parsed.rawDetailsFingerprint,
            totalPriceAmount: parsed.totalPriceAmount,
            totalPriceCurrency: parsed.totalPriceCurrency,
            roomCategory: parsed.roomCategory,
            boardType: BookingBoardType(rawValue: parsed.boardTypeRaw ?? "") ?? .unknown,
            includedBreakfast: parsed.includedBreakfast,
            guestCount: parsed.guestCount,
            roomCount: parsed.roomCount,
            airline: parsed.airline,
            passengerCount: parsed.passengerCount,
            baggageInfoRaw: parsed.baggageInfoRaw,
            lastParsedAt: Date()
        )
    }

    func mapBasketRateDetails(
        basket: HotelBasketParser.ParsedHotelBasket,
        details: ParsedBookingDetails?
    ) -> BookingRateDetails? {
        let roomItems = basket.items.map { item in
            BookingRoomItem(
                category: item.roomCategoryTitle,
                confirmationCode: item.bookingNumber,
                priceAmount: item.priceTotalAmount,
                priceCurrency: item.priceTotalCurrency,
                guestSummary: item.guestSummary,
                sortIndex: item.sortIndex
            )
        }

        guard !roomItems.isEmpty else { return nil }

        let uniqueCategories: [String] = {
            var seen = Set<String>()
            var ordered: [String] = []
            for item in roomItems {
                guard let cat = item.category?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !cat.isEmpty,
                      seen.insert(cat).inserted
                else { continue }
                ordered.append(cat)
            }
            return ordered
        }()

        let roomCount = basket.items.count
        let boardType = BookingBoardType(rawValue: details?.boardTypeRaw ?? "") ?? .unknown

        return BookingRateDetails(
            rawDetailsFingerprint: details?.rawDetailsFingerprint,
            totalPriceAmount: basket.basketPriceEffectiveAmount,
            totalPriceCurrency: basket.basketPriceCurrency,
            roomCategory: uniqueCategories.joined(separator: " + "),
            boardType: boardType,
            includedBreakfast: details?.includedBreakfast,
            guestCount: details?.guestCount,
            roomCount: roomCount,
            airline: details?.airline,
            passengerCount: details?.passengerCount,
            baggageInfoRaw: details?.baggageInfoRaw,
            roomItems: roomItems,
            lastParsedAt: Date()
        )
    }

    private func fetchActivitiesJSON(using webView: WKWebView) async throws -> String {
        guard let url = URL(string: "https://kundenbereich.check24.de/kb/api/activities") else {
            throw Check24ProviderError.activitiesFetchFailed("ungültige Activities-URL")
        }

        var lastDetail = "unbekannt"
        for attempt in 1...3 {
            do {
                let request = await webView.authenticatedRequest(url: url)
                let (data, response) = try await URLSession.shared.data(for: request)
                let status = (response as? HTTPURLResponse)?.statusCode ?? -1
                guard (200..<300).contains(status) else {
                    throw Check24ProviderError.activitiesFetchFailed("HTTP \(status)")
                }
                guard let text = String(data: data, encoding: .utf8) else {
                    throw Check24ProviderError.activitiesFetchFailed("Antwort ist kein UTF-8-Text")
                }
                guard text.contains("\"activities\"") else {
                    let preview = String(text.prefix(120)).replacingOccurrences(of: "\n", with: " ")
                    throw Check24ProviderError.activitiesFetchFailed(
                        "Antwort enthält keine activities (HTTP \(status)): \(preview)"
                    )
                }
                try persistActivitiesJSONSnapshot(text)
                return text
            } catch let error as Check24ProviderError {
                lastDetail = error.localizedDescription
                if attempt < 3 {
                    try await Task.sleep(nanoseconds: UInt64(attempt) * 400_000_000)
                    continue
                }
                throw error
            } catch {
                lastDetail = error.localizedDescription
                if attempt < 3 {
                    try await Task.sleep(nanoseconds: UInt64(attempt) * 400_000_000)
                    continue
                }
            }
        }
        throw Check24ProviderError.activitiesFetchFailed(lastDetail)
    }

    private func persistActivitiesJSONSnapshot(_ json: String) throws {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw Check24ProviderError.snapshotFailed
        }
        let base = appSupport.appendingPathComponent("Reisen", isDirectory: true)
        let snapshots = base.appendingPathComponent("snapshots", isDirectory: true)
        try FileManager.default.createDirectory(at: snapshots, withIntermediateDirectories: true)
        let fileName = "activities-\(ISO8601DateFormatter().string(from: Date())).json"
        let url = snapshots.appendingPathComponent(fileName)
        guard let data = json.data(using: .utf8) else {
            throw Check24ProviderError.snapshotFailed
        }
        try data.write(to: url, options: [.atomic])
    }

    private func snapshotHTML(from webView: WKWebView) async throws -> (url: URL, html: String) {
        guard let pageURL = webView.url else { throw Check24ProviderError.snapshotFailed }
        let html = try await webView.evaluateJavaScriptStringAsync("document.documentElement.outerHTML")
        guard let html else { throw Check24ProviderError.snapshotFailed }

        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw Check24ProviderError.snapshotFailed
        }
        let base = appSupport.appendingPathComponent("Reisen", isDirectory: true)
        let snapshots = base.appendingPathComponent("snapshots", isDirectory: true)
        try FileManager.default.createDirectory(at: snapshots, withIntermediateDirectories: true)
        let formatter = ISO8601DateFormatter()
        let fileName = "check24-\(formatter.string(from: Date())).html"
        let htmlURL = snapshots.appendingPathComponent(fileName)
        let metaURL = snapshots.appendingPathComponent(fileName + ".json")
        let meta: [String: Any] = [
            "createdAt": formatter.string(from: Date()),
            "pageURL": pageURL.absoluteString,
        ]
        try JSONSerialization.data(withJSONObject: meta, options: [.prettyPrinted]).write(to: metaURL, options: [.atomic])
        guard let htmlData = html.data(using: .utf8) else { throw Check24ProviderError.snapshotFailed }
        try htmlData.write(to: htmlURL, options: [.atomic])
        return (url: pageURL, html: html)
    }

    private func load(url: URL, in webView: WKWebView) async throws {
        try await NavigationAwaiter().load(url, in: webView)
        try await Task.sleep(nanoseconds: 400_000_000)
    }

    /// Check24 zeigt bei verknüpften Hotelbuchungen oft „Wählen Sie Ihre Buchung“ —
    /// ohne Klick fehlen Storno-/Detail-Daten. Passenden Eintrag automatisch wählen.
    private func dismissBookingChooserIfNeeded(
        in webView: WKWebView,
        for parsedBooking: ParsedBooking
    ) async {
        var needles: [String] = []
        if let title = parsedBooking.title, !title.isEmpty { needles.append(title) }
        if let code = parsedBooking.confirmationCode, !code.isEmpty { needles.append(code) }
        if let url = parsedBooking.externalUrl, let bookingID = url.split(separator: "/").last {
            needles.append(String(bookingID))
        }
        await dismissBookingChooserIfNeeded(in: webView, needles: needles)
    }

    private func dismissBookingChooserIfNeeded(
        in webView: WKWebView,
        needles: [String]
    ) async {
        let cleaned = needles
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let needlesJSON: String
        if let data = try? JSONSerialization.data(withJSONObject: cleaned),
           let text = String(data: data, encoding: .utf8) {
            needlesJSON = text
        } else {
            needlesJSON = "[]"
        }

        let script = """
        (function() {
          const needles = \(needlesJSON).map(s => String(s || '').toLowerCase()).filter(Boolean);
          const root = document.body;
          if (!root) return false;

          const hasChooser = /Wählen Sie Ihre Buchung/i.test(root.innerText || '');
          if (!hasChooser) return false;

          function visible(el) {
            if (!el) return false;
            const r = el.getBoundingClientRect();
            const style = window.getComputedStyle(el);
            return r.width > 8 && r.height > 8
              && style.visibility !== 'hidden'
              && style.display !== 'none'
              && style.opacity !== '0';
          }

          function score(el) {
            const text = (el.innerText || el.textContent || '').toLowerCase();
            let s = 0;
            for (const n of needles) {
              if (n && text.includes(n)) s += 10;
            }
            if (/aktiv/i.test(text)) s += 1;
            return s;
          }

          const candidates = Array.from(root.querySelectorAll('button, a, [role="button"], li, div'))
            .filter(visible)
            .filter(el => {
              const text = (el.innerText || '').trim();
              if (text.length < 8 || text.length > 800) return false;
              return /€|aktiv|zimmer|doppel|suite|buchung/i.test(text);
            });

          let best = null;
          let bestScore = 0;
          for (const el of candidates) {
            const s = score(el);
            if (s > bestScore) {
              bestScore = s;
              best = el;
            }
          }

          if (!best || bestScore < 1) {
            best = candidates.find(el => /€/.test(el.innerText || '')) || null;
          }
          if (!best) return false;

          best.click();
          return true;
        })();
        """

        for _ in 1...6 {
            let hasChooser = await webView.evaluateJavaScriptBoolAsync(
                "/Wählen Sie Ihre Buchung/i.test((document.body && document.body.innerText) || '')"
            )
            guard hasChooser else { return }

            _ = await webView.evaluateJavaScriptBoolAsync(script)
            try? await Task.sleep(nanoseconds: 450_000_000)

            let stillOpen = await webView.evaluateJavaScriptBoolAsync(
                "/Wählen Sie Ihre Buchung/i.test((document.body && document.body.innerText) || '')"
            )
            if !stillOpen { return }
        }
    }

    private func identityKey(for parsed: ParsedBooking) -> String? {
        if let url = parsed.externalUrl, !url.isEmpty { return "url:\(url)" }
        if let conf = parsed.confirmationCode, !conf.isEmpty {
            return "conf:\(conf)|start:\(parsed.startAt.timeIntervalSince1970)"
        }
        return nil
    }

    private func isHotelBookingDetailURL(_ url: URL) -> Bool {
        let host = (url.host ?? "").lowercased()
        let path = url.path.lowercased()
        return host.contains("hotel.check24.de") && path.contains("/kundenbereich/buchung/")
    }

    private func isNonHotelBookingDetailURL(_ url: URL) -> Bool {
        let host = (url.host ?? "").lowercased()
        let path = url.path.lowercased()
        return (host.contains("flug.check24.de") || host.contains("ferry.check24.de"))
            && path.contains("/kundenbereich/buchung/")
    }
}
