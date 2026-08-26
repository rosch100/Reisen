import Foundation
import ReisenDomain

enum TravelokaItineraryEntryParser {
    static func draft(
        from entry: [String: Any],
        routePrefix: String = TravelokaAPI.routePrefix
    ) throws -> ProviderBookingDraft {
        let bookingId = TravelokaJSON.string(entry["bookingId"])
        let itineraryId = TravelokaJSON.string(entry["itineraryId"])
        guard let bookingId, let itineraryId else {
            throw TravelokaProviderError.missingBookingIdentifiers
        }

        let product = TravelokaProductType(raw: TravelokaJSON.string(entry["itineraryType"]))
        let summary = TravelokaJSON.cardSummary(from: entry)
        let common = TravelokaJSON.commonSummary(from: entry)
        let detail = TravelokaJSON.cardDetail(from: entry)

        let tzBegin = TravelokaJSON.timeZone(iana: TravelokaJSON.string(common["ianaTimezoneBegin"]))
        let tzEnd = TravelokaJSON.timeZone(iana: TravelokaJSON.string(common["ianaTimezoneEnd"]))

        guard let startAt = TravelokaJSON.dateFromMillis(common["itineraryTimestampBegin"]) else {
            throw TravelokaProviderError.missingItineraryTimestamps
        }
        // Fehlendes Ende = gleicher Instant wie Start (explizit, kein Epoch-Dummy).
        let endAt = TravelokaJSON.dateFromMillis(common["itineraryTimestampEnd"]) ?? startAt

        var resolvedStart = startAt
        var resolvedEnd = endAt
        var title: String?
        var locationFrom: String?
        var locationTo: String?
        var locationFromAddress: String?
        var locationToAddress: String?
        var operatorName: String?
        var isAllDay: Bool?
        var rateDetails: BookingRateDetails?
        var hotelCheckInMinutes: Int?
        var hotelCheckOutMinutes: Int?
        var hotelOffsetSeconds: Int? = tzBegin.map { $0.secondsFromGMT(for: startAt) }
        var flightDepartureOffsetSeconds: Int?
        var flightArrivalOffsetSeconds: Int?
        var passengers: [BookingPassenger] = []
        var deadlines: [CancellationDeadline] = []

        switch product {
        case .experience:
            let expSummary = (summary["experienceSummary"] as? [String: Any]) ?? [:]
            let expDetail = (detail["experienceDetail"] as? [String: Any]) ?? [:]
            title = TravelokaJSON.string(expDetail["experienceName"])
                ?? TravelokaJSON.string(expSummary["experienceName"])
            locationTo = TravelokaJSON.string(expDetail["location"])
                ?? TravelokaJSON.string(expSummary["location"])
            let makeOwn = expDetail["makeYourOwnWayInfo"] as? [String: Any]
            locationToAddress = TravelokaJSON.string(makeOwn?["locationName"])
            operatorName = TravelokaJSON.string((expDetail["operatorInfo"] as? [String: Any])?["name"])
            let timeSlot = TravelokaJSON.string(expDetail["timeSlot"])
                ?? TravelokaJSON.string(expSummary["timeSlot"])
            let timeSlotId = TravelokaJSON.string(expDetail["timeSlotId"])
                ?? TravelokaJSON.string(expSummary["timeSlotId"])
            isAllDay = (timeSlotId?.localizedCaseInsensitiveContains("all_day") == true)
                || (timeSlot?.localizedCaseInsensitiveContains("all day") == true)
            let option = TravelokaJSON.string(expDetail["ticketName"])
            let guestLabel = TravelokaJSON.string(expDetail["selectedTicketDisplay"])
            rateDetails = BookingRateDetails(
                roomCategory: option,
                guestCount: guestCount(fromDisplay: guestLabel)
            )
            if let day = TravelokaJSON.dayComponents(expDetail["ticketDate"] ?? expSummary["ticketDate"]),
               let beginTZ = tzBegin
            {
                if let dayStart = TravelokaJSON.dateFromDay(
                    day,
                    minutes: isAllDay == true ? 0 : nil,
                    timeZone: beginTZ
                ) {
                    resolvedStart = dayStart
                }
                let endTZ = tzEnd ?? beginTZ
                if let dayEnd = TravelokaJSON.dateFromDay(
                    day,
                    minutes: isAllDay == true ? 23 * 60 + 59 : nil,
                    timeZone: endTZ
                ) {
                    resolvedEnd = dayEnd
                }
            }
            passengers = experiencePassengers(from: expDetail, common: common, cardDetail: detail)
            if let beginTZ = tzBegin {
                deadlines = experienceDeadlines(from: expDetail, timeZone: beginTZ)
            }

        case .hotel:
            let hotelSummary = (summary["hotelSummary"] as? [String: Any]) ?? [:]
            let hotelDetail = (detail["hotelDetail"] as? [String: Any]) ?? [:]
            title = TravelokaJSON.string(hotelDetail["hotelName"])
                ?? TravelokaJSON.string(hotelSummary["hotelName"])
            locationTo = TravelokaJSON.string(hotelDetail["cityName"])
                ?? TravelokaJSON.string(hotelSummary["cityName"])
            locationToAddress = TravelokaJSON.string(hotelDetail["address"])
            hotelCheckInMinutes = TravelokaJSON.minutesFromHHMM(
                TravelokaJSON.string(hotelDetail["checkInTime"] ?? hotelSummary["checkInTime"])
            )
            hotelCheckOutMinutes = TravelokaJSON.minutesFromHHMM(
                TravelokaJSON.string(hotelDetail["checkOutTime"] ?? hotelSummary["checkOutTime"])
            )
            if let inDay = TravelokaJSON.dayComponents(hotelSummary["checkInDate"]),
               let outDay = TravelokaJSON.dayComponents(hotelSummary["checkOutDate"]),
               let beginTZ = tzBegin
            {
                let endTZ = tzEnd ?? beginTZ
                if let inDate = TravelokaJSON.dateFromDay(inDay, minutes: hotelCheckInMinutes, timeZone: beginTZ) {
                    resolvedStart = inDate
                }
                if let outDate = TravelokaJSON.dateFromDay(outDay, minutes: hotelCheckOutMinutes, timeZone: endTZ) {
                    resolvedEnd = outDate
                }
            }
            let breakfast = TravelokaJSON.bool(hotelDetail["breakfastIncluded"] ?? hotelSummary["breakfastIncluded"])
            let boardType: BookingBoardType = {
                guard let breakfast else { return .unknown }
                return breakfast ? .breakfastIncluded : .roomOnly
            }()
            rateDetails = BookingRateDetails(
                roomCategory: TravelokaJSON.string(hotelDetail["roomName"] ?? hotelSummary["roomName"]),
                boardType: boardType,
                includedBreakfast: breakfast,
                guestCount: TravelokaJSON.int(hotelDetail["guestCount"] ?? hotelSummary["guestCount"]),
                roomCount: TravelokaJSON.int(hotelDetail["roomCount"] ?? hotelSummary["roomCount"])
            )
            if let beginTZ = tzBegin {
                deadlines = hotelDeadlines(from: hotelDetail, timeZone: beginTZ)
            }
            if let contact = common["bookingContact"] as? [String: Any] {
                passengers = [passenger(from: contact, type: .adult)].compactMap { $0 }
            }

        case .vehicleRental:
            let vSummary = (summary["vehicleRentalSummaryInfo"] as? [String: Any]) ?? [:]
            let vDetail = (detail["vehicleRentalDetailInfo"] as? [String: Any]) ?? [:]
            title = TravelokaJSON.string(vDetail["vehicleName"] ?? vSummary["vehicleName"])
            operatorName = TravelokaJSON.string(vDetail["providerName"] ?? vSummary["providerName"])
            locationFrom = TravelokaJSON.string(vSummary["pickUpAddress"])
            locationFromAddress = TravelokaJSON.string(vDetail["pickUpAddress"] ?? vSummary["pickUpAddress"])
            locationTo = TravelokaJSON.string(vSummary["dropOffAddress"])
            locationToAddress = TravelokaJSON.string(vDetail["dropOffAddress"] ?? vSummary["dropOffAddress"])
            rateDetails = BookingRateDetails(
                roomCategory: TravelokaJSON.string(vDetail["transmission"] ?? vSummary["transmission"])
            )
            if let beginTZ = tzBegin,
               let freeUntil = TravelokaJSON.string(vDetail["freeCancellationDeadlineLocal"]),
               let deadline = TravelokaCancellationDeadlines.free(local: freeUntil, timeZone: beginTZ)
            {
                deadlines = [deadline]
            }
            if let traveler = TravelokaJSON.string(vDetail["travelerName"]) {
                passengers = [
                    BookingPassenger(
                        passengerNumber: 1,
                        travellerType: .adult,
                        givenName: traveler
                    ),
                ]
            }

        case .flight:
            let flightDetail = (detail["flightDetail"] as? [String: Any]) ?? [:]
            let originCity = TravelokaJSON.string(flightDetail["originCity"])
            let destCity = TravelokaJSON.string(flightDetail["destinationCity"])
            let originCode = TravelokaJSON.string(flightDetail["originAirportCode"])
            let destCode = TravelokaJSON.string(flightDetail["destinationAirportCode"])
            if let originCity, let destCity {
                title = "\(originCity) → \(destCity)"
            }
            locationFrom = [originCity, originCode].compactMap { $0 }.joined(separator: " ")
            locationTo = [destCity, destCode].compactMap { $0 }.joined(separator: " ")
            locationFromAddress = [
                TravelokaJSON.string(flightDetail["originAirportName"]),
                TravelokaJSON.string(flightDetail["originTerminal"]).map { "Terminal \($0)" },
            ].compactMap { $0 }.joined(separator: ", ")
            locationToAddress = [
                TravelokaJSON.string(flightDetail["destinationAirportName"]),
                TravelokaJSON.string(flightDetail["destinationTerminal"]).map { "Terminal \($0)" },
            ].compactMap { $0 }.joined(separator: ", ")
            if let beginTZ = tzBegin {
                flightDepartureOffsetSeconds = beginTZ.secondsFromGMT(for: resolvedStart)
            }
            if let endTZ = tzEnd {
                flightArrivalOffsetSeconds = endTZ.secondsFromGMT(for: resolvedEnd)
            }
            hotelOffsetSeconds = nil
            let cabin = TravelokaJSON.string(flightDetail["cabinBaggage"])
            let checked = TravelokaJSON.string(flightDetail["checkedBaggage"])
            let baggage = [cabin.map { "Cabin \($0)" }, checked.map { "Checked \($0)" }]
                .compactMap { $0 }
                .joined(separator: "; ")
            rateDetails = BookingRateDetails(
                airline: TravelokaJSON.string(flightDetail["airlineName"]),
                passengerCount: TravelokaJSON.int(flightDetail["passengerCount"]),
                baggageInfoRaw: baggage.isEmpty ? nil : baggage
            )
            passengers = flightPassengers(from: flightDetail)
            deadlines = flightDeadlines(from: flightDetail, timeZone: tzBegin)

        case .airportTransport, .flightAncillary, .insurance, .train, .other:
            title = TravelokaJSON.string(common["productName"]) ?? product.rawValue
        }

        let externalUrl = TravelokaAPI.detailURL(
            bookingId: bookingId,
            itineraryId: itineraryId,
            productType: product == .other
                ? (TravelokaJSON.string(entry["itineraryType"]) ?? "OTHER")
                : product.rawValue,
            routePrefix: routePrefix
        ).absoluteString

        return ProviderBookingDraft(
            provider: .traveloka,
            bookingType: product.bookingType,
            title: title,
            confirmationCode: bookingId,
            externalUrl: externalUrl,
            startAt: resolvedStart,
            endAt: resolvedEnd,
            locationFrom: emptyToNil(locationFrom),
            locationTo: emptyToNil(locationTo),
            locationFromAddress: emptyToNil(locationFromAddress),
            locationToAddress: emptyToNil(locationToAddress),
            operatorName: operatorName,
            isAllDay: isAllDay,
            status: TravelokaStatusMapper.status(from: entry),
            deadlines: deadlines,
            rateDetails: rateDetails,
            hotelOffsetSeconds: product.bookingType == .hotel || product.bookingType == .activity || product.bookingType == .other
                ? hotelOffsetSeconds
                : nil,
            hotelCheckInMinutes: hotelCheckInMinutes,
            hotelCheckOutMinutes: hotelCheckOutMinutes,
            flightDepartureOffsetSeconds: flightDepartureOffsetSeconds,
            flightArrivalOffsetSeconds: flightArrivalOffsetSeconds,
            rawPayloadFingerprint: "\(bookingId):\(itineraryId)",
            passengers: passengers
        )
    }

    static func enrichment(from entry: [String: Any]) throws -> ProviderBookingEnrichment {
        let draft = try draft(from: entry)
        return ProviderBookingEnrichment(
            deadlines: draft.deadlines,
            rateDetails: draft.rateDetails,
            passengers: draft.passengers.isEmpty ? nil : draft.passengers,
            hotelOffsetSeconds: draft.hotelOffsetSeconds,
            hotelCheckInMinutes: draft.hotelCheckInMinutes,
            hotelCheckOutMinutes: draft.hotelCheckOutMinutes,
            flightDepartureOffsetSeconds: draft.flightDepartureOffsetSeconds,
            flightArrivalOffsetSeconds: draft.flightArrivalOffsetSeconds,
            status: draft.status,
            title: draft.title,
            locationFrom: draft.locationFrom,
            locationTo: draft.locationTo,
            locationFromAddress: draft.locationFromAddress,
            locationToAddress: draft.locationToAddress,
            operatorName: draft.operatorName,
            isAllDay: draft.isAllDay
        )
    }

    private static func emptyToNil(_ value: String?) -> String? {
        guard let value else { return nil }
        let t = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }

    private static func passenger(from contact: [String: Any], type: TravellerType) -> BookingPassenger? {
        let given = TravelokaJSON.string(contact["firstName"])
        let family = TravelokaJSON.string(contact["lastName"])
        if given == nil && family == nil { return nil }
        return BookingPassenger(
            passengerNumber: 1,
            travellerType: type,
            givenName: given,
            familyName: family
        )
    }

    private static func experiencePassengers(
        from experienceDetail: [String: Any],
        common: [String: Any],
        cardDetail: [String: Any]
    ) -> [BookingPassenger] {
        let type = experienceTravellerType(from: experienceDetail) ?? .adult
        if let list = (experienceDetail["additionalBookingInformation"] as? [String: Any])?["travelerList"] as? [[String: Any]],
           !list.isEmpty
        {
            return list.enumerated().compactMap { index, item in
                let name = TravelokaJSON.string(item["title"])
                    ?? nameFromInfoList(item["infoList"] as? [[String: Any]])
                guard let name else { return nil }
                return BookingPassenger(
                    passengerNumber: index + 1,
                    travellerType: type,
                    givenName: name
                )
            }
        }
        if let contact = (common["bookingContact"] as? [String: Any])
            ?? ((cardDetail["commonDetail"] as? [String: Any])?["bookingContact"] as? [String: Any])
        {
            return [passenger(from: contact, type: type)].compactMap { $0 }
        }
        return []
    }

    private static func experienceTravellerType(from detail: [String: Any]) -> TravellerType? {
        if let infos = detail["travelersInfo"] as? [[String: Any]] {
            for info in infos {
                if let t = travellerType(
                    fromToken: TravelokaJSON.string(info["entranceTypeId"])
                        ?? TravelokaJSON.string(info["entranceTypeTitle"])
                ) {
                    return t
                }
            }
        }
        if let barcodes = detail["barCodeInfos"] as? [[String: Any]] {
            for code in barcodes {
                if let t = travellerType(fromToken: TravelokaJSON.string(code["experiencePaxType"])) {
                    return t
                }
            }
        }
        return travellerType(fromDisplay: TravelokaJSON.string(detail["selectedTicketDisplay"]))
    }

    private static func nameFromInfoList(_ list: [[String: Any]]?) -> String? {
        guard let list else { return nil }
        for item in list where TravelokaJSON.string(item["id"]) == "name" {
            return TravelokaJSON.string(item["label"])
        }
        return nil
    }

    private static func flightPassengers(from detail: [String: Any]) -> [BookingPassenger] {
        let list = (detail["passengers"] as? [[String: Any]])
            ?? (detail["passengerList"] as? [[String: Any]])
            ?? []
        return list.enumerated().compactMap { index, item in
            let given = TravelokaJSON.string(item["firstName"] ?? item["givenName"])
            let family = TravelokaJSON.string(item["lastName"] ?? item["familyName"])
            if given == nil && family == nil { return nil }
            let type = travellerType(fromToken: TravelokaJSON.string(item["type"] ?? item["passengerType"]))
                ?? .adult
            return BookingPassenger(
                passengerNumber: index + 1,
                travellerType: type,
                givenName: given,
                familyName: family
            )
        }
    }

    private static func travellerType(fromToken token: String?) -> TravellerType? {
        guard let token else { return nil }
        let lower = token.lowercased()
        if lower.contains("child") || lower == "chd" { return .child }
        if lower.contains("adult") || lower == "adt" { return .adult }
        return nil
    }

    private static func travellerType(fromDisplay label: String?) -> TravellerType? {
        guard let label else { return nil }
        let lower = label.lowercased()
        if lower.contains("child") { return .child }
        if lower.contains("adult") { return .adult }
        return nil
    }

    private static func guestCount(fromDisplay label: String?) -> Int? {
        let numbers = allInts(in: label ?? "")
        guard !numbers.isEmpty else { return nil }
        return numbers.reduce(0, +)
    }

    private static func experienceDeadlines(
        from detail: [String: Any],
        timeZone: TimeZone
    ) -> [CancellationDeadline] {
        if let freeUntil = TravelokaJSON.string(detail["freeCancellationDeadlineLocal"]),
           let deadline = TravelokaCancellationDeadlines.free(local: freeUntil, timeZone: timeZone)
        {
            return [deadline]
        }
        let policies = detail["cancellationPolicies"] as? [String] ?? []
        for policy in policies {
            if let days = firstInt(in: policy),
               policy.localizedCaseInsensitiveContains("prior"),
               policy.localizedCaseInsensitiveContains("100%"),
               let ticketDay = TravelokaJSON.dayComponents(detail["ticketDate"])
            {
                guard var base = TravelokaJSON.dateFromDay(ticketDay, minutes: 23 * 60 + 59, timeZone: timeZone)
                else { continue }
                base = Calendar(identifier: .gregorian).date(byAdding: .day, value: -days, to: base) ?? base
                return [
                    TravelokaCancellationDeadlines.at(
                        base,
                        timeZone: timeZone,
                        policyText: policy,
                        isFreeCancellation: true
                    ),
                ]
            }
        }
        return []
    }

    private static func hotelDeadlines(
        from detail: [String: Any],
        timeZone: TimeZone
    ) -> [CancellationDeadline] {
        let policies = detail["cancellationPolicies"] as? [[String: Any]] ?? []
        var result: [CancellationDeadline] = []
        for policy in policies {
            guard let type = TravelokaJSON.string(policy["type"])?.uppercased() else { continue }
            let local = TravelokaJSON.string(policy["deadlineLocal"])
            guard let local else { continue }
            switch type {
            case "FREE":
                if let deadline = TravelokaCancellationDeadlines.free(local: local, timeZone: timeZone) {
                    result.append(deadline)
                }
            case "FEE":
                if let deadline = TravelokaCancellationDeadlines.fee(
                    local: local,
                    timeZone: timeZone,
                    policyText: "Cancellation fee",
                    feeAmount: TravelokaJSON.double(policy["feeAmount"])
                ) {
                    result.append(deadline)
                }
            default:
                // Unbekannte Typen nicht als Free interpretieren.
                continue
            }
        }
        return result
    }

    private static func flightDeadlines(
        from detail: [String: Any],
        timeZone: TimeZone?
    ) -> [CancellationDeadline] {
        if TravelokaJSON.bool(detail["refundable"]) == false {
            return []
        }
        if let label = TravelokaJSON.string(detail["refundPolicyLabel"]),
           label.localizedCaseInsensitiveContains("non-refundable")
        {
            return []
        }
        // Fee-Refund: nur mit echter Deadline + Fee aus API (keine Free-Deadline erfinden).
        guard let fee = TravelokaJSON.double(detail["refundFeeAmount"]),
              let local = TravelokaJSON.string(detail["refundDeadlineLocal"]),
              let tz = timeZone,
              let deadline = TravelokaCancellationDeadlines.fee(
                  local: local,
                  timeZone: tz,
                  policyText: TravelokaJSON.string(detail["refundPolicyLabel"]) ?? "Refund with fee",
                  feeAmount: fee
              )
        else {
            return []
        }
        return [deadline]
    }

    private static let digitRegex = try? NSRegularExpression(pattern: #"\d+"#)

    private static func firstInt(in text: String) -> Int? {
        guard let match = digitRegex?.firstMatch(
            in: text,
            range: NSRange(location: 0, length: (text as NSString).length)
        ) else { return nil }
        return Int((text as NSString).substring(with: match.range))
    }

    private static func allInts(in text: String) -> [Int] {
        guard let digitRegex else { return [] }
        let ns = text as NSString
        return digitRegex.matches(in: text, range: NSRange(location: 0, length: ns.length))
            .compactMap { Int(ns.substring(with: $0.range)) }
    }
}
