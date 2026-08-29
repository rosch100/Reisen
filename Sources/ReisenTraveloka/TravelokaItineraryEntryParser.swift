import Foundation
import ReisenDomain

enum TravelokaItineraryEntryParser {
    static func draft(
        from entry: [String: Any],
        routePrefix: String = TravelokaAPI.routePrefix
    ) throws -> ProviderBookingDraft? {
        guard let facts = try facts(from: entry, routePrefix: routePrefix) else {
            return nil
        }
        return DraftAssembler.draft(from: facts)
    }

    static func enrichment(from entry: [String: Any]) throws -> ProviderBookingEnrichment {
        guard let facts = try facts(from: entry) else {
            throw TravelokaProviderError.missingItineraryTimestamps
        }
        return DraftAssembler.enrichment(from: facts)
    }

    private static func facts(
        from entry: [String: Any],
        routePrefix: String = TravelokaAPI.routePrefix
    ) throws -> ProviderBookingFacts? {
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

        guard let startAt = TravelokaJSON.dateFromMillis(common["itineraryTimestampBegin"]),
              let endAt = TravelokaJSON.dateFromMillis(common["itineraryTimestampEnd"]) else {
            return nil
        }
        var fields = productFields(
            from: EntryContext(
                entry: entry,
                product: product,
                summary: summary,
                common: common,
                detail: detail,
                tzBegin: tzBegin,
                tzEnd: tzEnd,
                startAt: startAt,
                endAt: endAt
            )
        )
        let bookingPrice = TravelokaJSON.bookingMoney(from: entry).map {
            BookingRateDetails(
                totalPriceAmount: $0.amount,
                totalPriceCurrency: $0.currency
            )
        }
        fields.rateDetails = BookingRateDetails.merging(
            existing: fields.rateDetails,
            incoming: bookingPrice
        )

        let externalUrl = TravelokaAPI.detailURL(
            bookingId: bookingId,
            itineraryId: itineraryId,
            productType: product == .other
                ? (TravelokaJSON.string(entry["itineraryType"]) ?? "OTHER")
                : product.rawValue,
            routePrefix: routePrefix
        ).absoluteString

        let times = TemporalFact.pair(
            bookingType: product.bookingType,
            start: fields.start,
            end: fields.end,
            hotelOffsetSeconds: fields.hotelOffsetSeconds
        )
        return ProviderBookingFacts(
            provider: .traveloka,
            bookingType: product.bookingType,
            start: times.start,
            end: times.end,
            title: fields.title,
            confirmationCode: bookingId,
            externalUrl: externalUrl,
            locationFrom: TravelokaJSON.string(fields.locationFrom),
            locationTo: TravelokaJSON.string(fields.locationTo),
            locationFromAddress: TravelokaJSON.string(fields.locationFromAddress),
            locationToAddress: TravelokaJSON.string(fields.locationToAddress),
            operatorName: fields.operatorName,
            isAllDay: fields.isAllDay,
            statusRaw: TravelokaStatusMapper.statusRaw(from: entry),
            deadlines: fields.deadlines,
            rateDetails: fields.rateDetails,
            hotelOffsetSeconds: fields.hotelOffsetSeconds,
            hotelCheckInMinutes: fields.hotelCheckInMinutes,
            hotelCheckOutMinutes: fields.hotelCheckOutMinutes,
            flightDepartureOffsetSeconds: fields.flightDepartureOffsetSeconds,
            flightArrivalOffsetSeconds: fields.flightArrivalOffsetSeconds,
            rawPayloadFingerprint: "\(bookingId):\(itineraryId)",
            passengers: fields.passengers,
            guestHints: fields.guestHints
        )
    }

    private struct EntryContext {
        let entry: [String: Any]
        let product: TravelokaProductType
        let summary: [String: Any]
        let common: [String: Any]
        let detail: [String: Any]
        let tzBegin: TimeZone?
        let tzEnd: TimeZone?
        let startAt: Date
        let endAt: Date
    }

    private struct ProductFields {
        var start: Date
        var end: Date
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
        var hotelOffsetSeconds: Int?
        var flightDepartureOffsetSeconds: Int?
        var flightArrivalOffsetSeconds: Int?
        var passengers: [BookingPassenger] = []
        var deadlines: [CancellationDeadline] = []
        var guestHints: [BookingGuestHint] = []
    }

    private static func productFields(from context: EntryContext) -> ProductFields {
        switch context.product {
        case .experience:
            return experienceFields(from: context)
        case .hotel:
            return hotelFields(from: context)
        case .vehicleRental:
            return vehicleFields(from: context)
        case .flight:
            return flightFields(from: context)
        case .train, .trainGlobal:
            return trainFields(from: context)
        case .airportTransport, .flightAncillary, .insurance, .other:
            var fields = baseFields(from: context)
            fields.title = TravelokaJSON.string(context.common["productName"]) ?? context.product.rawValue
            return fields
        }
    }

    private static func baseFields(from context: EntryContext) -> ProductFields {
        ProductFields(
            start: context.startAt,
            end: context.endAt,
            hotelOffsetSeconds: context.tzBegin.map { $0.secondsFromGMT(for: context.startAt) }
        )
    }

    private static func experienceFields(from context: EntryContext) -> ProductFields {
        var fields = baseFields(from: context)
        let expSummary = TravelokaJSON.dictionary(context.summary["experienceSummary"])
        let expDetail = TravelokaJSON.dictionary(context.detail["experienceDetail"])
        fields.title = TravelokaJSON.string(fromKeys: ["experienceName"], in: [expDetail, expSummary])
        fields.locationTo = TravelokaJSON.string(fromKeys: ["location"], in: [expDetail, expSummary])
        fields.locationToAddress = TravelokaJSON.string(
            TravelokaJSON.dictionary(expDetail["makeYourOwnWayInfo"])["locationName"]
        )
        fields.operatorName = TravelokaJSON.string(
            TravelokaJSON.dictionary(expDetail["operatorInfo"])["name"]
        )
        let timeSlot = TravelokaJSON.string(fromKeys: ["timeSlot"], in: [expDetail, expSummary])
        let timeSlotId = TravelokaJSON.string(fromKeys: ["timeSlotId"], in: [expDetail, expSummary])
        fields.isAllDay = (timeSlotId?.localizedCaseInsensitiveContains("all_day") == true)
            || (timeSlot?.localizedCaseInsensitiveContains("all day") == true)
        fields.rateDetails = BookingRateDetails(
            roomCategory: TravelokaJSON.string(expDetail["ticketName"]),
            guestCount: guestCount(fromDisplay: TravelokaJSON.string(expDetail["selectedTicketDisplay"]))
        )
        if let day = TravelokaJSON.dayComponents(expDetail["ticketDate"] ?? expSummary["ticketDate"]),
           let beginTZ = context.tzBegin
        {
            if let dayStart = TravelokaJSON.dateFromDay(
                day,
                minutes: fields.isAllDay == true ? 0 : nil,
                timeZone: beginTZ
            ) {
                fields.start = dayStart
            }
            if let dayEnd = TravelokaJSON.dateFromDay(
                day,
                minutes: fields.isAllDay == true ? 23 * 60 + 59 : nil,
                timeZone: context.tzEnd ?? beginTZ
            ) {
                fields.end = dayEnd
            }
        }
        fields.passengers = experiencePassengers(
            from: expDetail,
            common: context.common,
            cardDetail: context.detail
        )
        if let beginTZ = context.tzBegin {
            fields.deadlines = experienceDeadlines(from: expDetail, timeZone: beginTZ)
        }
        return fields
    }

    private static func hotelFields(from context: EntryContext) -> ProductFields {
        var fields = baseFields(from: context)
        let hotelSummary = TravelokaJSON.dictionary(context.summary["hotelSummary"])
        let hotelDetail = TravelokaJSON.dictionary(context.detail["hotelDetail"])
        let voucher = TravelokaJSON.hotelVoucher(from: context.entry, hotelDetail: hotelDetail)
        let localeInfo = TravelokaJSON.localeAwareInfo(from: voucher)
        let bookingHotel = TravelokaJSON.dictionary(
            TravelokaJSON.dictionary(context.entry["bookingInfo"])["hotelBookingInfo"]
        )
        fields.title = TravelokaJSON.string(
            fromKeys: ["hotelName"],
            in: [localeInfo, hotelDetail, hotelSummary, bookingHotel]
        )
        fields.locationTo = TravelokaJSON.firstString([
            bookingHotel["hotelGeoDisplayName"],
            TravelokaJSON.translatedCity(from: localeInfo),
            TravelokaJSON.value(fromKeys: ["cityName"], in: [hotelDetail, hotelSummary]),
        ])
        fields.locationToAddress = TravelokaJSON.firstString([
            localeInfo["hotelAddress"],
            hotelDetail["address"],
        ])
        fields.hotelCheckInMinutes = TravelokaJSON.minutesFromTime(
            TravelokaJSON.value(fromKeys: ["checkInTime"], in: [voucher, hotelDetail, hotelSummary])
        )
        fields.hotelCheckOutMinutes = TravelokaJSON.minutesFromTime(
            TravelokaJSON.value(fromKeys: ["checkOutTime"], in: [voucher, hotelDetail, hotelSummary])
        )
        if let inDay = TravelokaJSON.dayComponents(
            TravelokaJSON.value(fromKeys: ["checkInDate"], in: [voucher, hotelSummary])
        ),
            let outDay = TravelokaJSON.dayComponents(
                TravelokaJSON.value(fromKeys: ["checkOutDate"], in: [voucher, hotelSummary])
            ),
            let beginTZ = context.tzBegin
        {
            if let inDate = TravelokaJSON.dateFromDay(
                inDay,
                minutes: fields.hotelCheckInMinutes,
                timeZone: beginTZ
            ) {
                fields.start = inDate
            }
            if let outDate = TravelokaJSON.dateFromDay(
                outDay,
                minutes: fields.hotelCheckOutMinutes,
                timeZone: context.tzEnd ?? beginTZ
            ) {
                fields.end = outDate
            }
        }
        let breakfast = TravelokaJSON.bool(
            TravelokaJSON.value(fromKeys: ["breakfastIncluded"], in: [voucher, hotelDetail, hotelSummary])
        )
        fields.rateDetails = BookingRateDetails(
            roomCategory: TravelokaJSON.firstString([
                localeInfo["roomType"],
                hotelDetail["roomName"],
                hotelSummary["roomName"],
            ]),
            boardType: BookingBoardType.parse(breakfastIncluded: breakfast),
            includedBreakfast: breakfast,
            guestCount: TravelokaJSON.int(
                voucher["numGuests"] ?? hotelDetail["guestCount"] ?? hotelSummary["guestCount"]
            ),
            roomCount: TravelokaJSON.int(
                voucher["numRooms"] ?? hotelDetail["roomCount"] ?? hotelSummary["roomCount"]
            )
        )
        if let beginTZ = context.tzBegin {
            fields.deadlines = hotelDeadlines(
                from: hotelDetail,
                localeInfo: localeInfo,
                bookingHotel: bookingHotel,
                timeZone: beginTZ
            )
        }
        fields.passengers = namedPassengers(
            contact: context.common["bookingContact"] as? [String: Any],
            fallbackName: TravelokaJSON.string(voucher["guestName"])
        )
        fields.guestHints = TravelokaGuestHintMapper.hints(
            localeInfo: localeInfo,
            bookingHotel: bookingHotel,
            voucher: voucher
        )
        return fields
    }

    private static func vehicleFields(from context: EntryContext) -> ProductFields {
        var fields = baseFields(from: context)
        let vSummary = TravelokaJSON.dictionary(context.summary["vehicleRentalSummaryInfo"])
        let vDetail = TravelokaJSON.dictionary(context.detail["vehicleRentalDetailInfo"])
        let withoutDriver = TravelokaJSON.dictionary(vDetail["withoutDriverDetailInfo"])
        let vehicleProduct = TravelokaJSON.dictionary(withoutDriver["product"])
        fields.title = vehicleTitle(
            name: TravelokaJSON.string(fromKeys: ["vehicleName", "productName", "header"], in: vDetail)
                ?? TravelokaJSON.string(fromKeys: ["vehicleName", "header"], in: vSummary),
            routeName: TravelokaJSON.string(fromKeys: ["routeName"], in: [vSummary, vDetail])
        )
        fields.operatorName = TravelokaJSON.string(
            fromKeys: ["supplierName", "providerName"],
            in: [vDetail, withoutDriver, vSummary]
        )
        fields.locationFrom = TravelokaJSON.string(
            fromKeys: ["pickupAddress", "pickUpAddress", "pickupLocation"],
            in: vSummary
        ) ?? TravelokaJSON.string(
            fromKeys: ["pickupLocation", "pickupAddress", "pickUpAddress"],
            in: vDetail
        )
        fields.locationFromAddress = TravelokaJSON.string(
            fromKeys: ["pickupLocation", "pickupAddress", "pickUpAddress"],
            in: vDetail
        ) ?? TravelokaJSON.string(fromKeys: ["pickupLocation"], in: withoutDriver)
            ?? TravelokaJSON.string(fromKeys: ["pickupAddress", "pickUpAddress"], in: vSummary)
        fields.locationTo = TravelokaJSON.string(
            fromKeys: ["dropOffAddress", "dropoffAddress", "dropoffLocation"],
            in: vSummary
        ) ?? TravelokaJSON.string(fromKeys: ["dropoffLocation", "dropOffAddress"], in: vDetail)
        fields.locationToAddress = TravelokaJSON.string(
            fromKeys: ["dropoffLocation", "dropOffAddress", "dropoffAddress"],
            in: vDetail
        ) ?? TravelokaJSON.string(fromKeys: ["dropoffLocation"], in: withoutDriver)
        fields.rateDetails = BookingRateDetails(
            roomCategory: TravelokaJSON.firstString([
                vehicleProduct["transmissionTypeLabel"],
                vDetail["transmission"],
                vSummary["transmission"],
            ]) ?? transmissionLabel(fromDetail: TravelokaJSON.string(vSummary["detail"]))
        )
        if let beginTZ = context.tzBegin {
            let startDay = TravelokaJSON.dayComponents(
                TravelokaJSON.value(fromKeys: ["startDate"], in: [vDetail, vSummary, withoutDriver])
            )
            let startMinutes = TravelokaJSON.minutesFromTime(
                vDetail["pickupTime"] ?? vSummary["pickupTime"] ?? withoutDriver["startTime"]
            )
            let endDay = TravelokaJSON.dayComponents(
                TravelokaJSON.value(fromKeys: ["endDate"], in: [vDetail, withoutDriver])
            )
            let endMinutes = TravelokaJSON.minutesFromTime(withoutDriver["endTime"])
            if let startDay,
               let inDate = TravelokaJSON.dateFromDay(startDay, minutes: startMinutes, timeZone: beginTZ)
            {
                fields.start = inDate
            }
            if let endDay,
               let outDate = TravelokaJSON.dateFromDay(
                   endDay,
                   minutes: endMinutes,
                   timeZone: context.tzEnd ?? beginTZ
               )
            {
                fields.end = outDate
            }
            fields.deadlines = vehicleDeadlines(from: vDetail, pickupAt: fields.start, timeZone: beginTZ)
        }
        fields.passengers = namedPassengers(
            contact: (vDetail["passengerContact"] as? [String: Any])
                ?? (withoutDriver["passengerContact"] as? [String: Any]),
            fallbackName: TravelokaJSON.string(vDetail["travelerName"])
        )
        return fields
    }

    /// Ohne TRAIN-Detail-HAR: nur bekannte Common-Felder; Bahnhöfe/Betreiber bleiben leer.
    /// `itineraryTimestamp*` bleibt Instant; IANA-Offsets nur für Ortszeit-Anzeige.
    private static func trainFields(from context: EntryContext) -> ProductFields {
        var fields = baseFields(from: context)
        fields.title = TravelokaJSON.string(context.common["productName"]) ?? context.product.rawValue
        if let beginTZ = context.tzBegin {
            fields.flightDepartureOffsetSeconds = beginTZ.secondsFromGMT(for: fields.start)
        }
        if let endTZ = context.tzEnd {
            fields.flightArrivalOffsetSeconds = endTZ.secondsFromGMT(for: fields.end)
        }
        return fields
    }

    private static func flightFields(from context: EntryContext) -> ProductFields {
        var fields = baseFields(from: context)
        let flightDetail = TravelokaJSON.dictionary(context.detail["flightDetail"])
        let bookingDetail = TravelokaJSON.flightBookingDetail(from: context.entry)
        let ticketInfo = TravelokaJSON.dictionary(context.entry["flightTicketInfo"])
        let eTicket = TravelokaJSON.localizedMapValue(ticketInfo["eTicketDetailMap"])
        let segments = TravelokaJSON.flightSegments(bookingDetail: bookingDetail, eTicket: eTicket)
        let firstSegment = segments.first ?? [:]
        let lastSegment = segments.last ?? firstSegment
        let originAirport = TravelokaJSON.flightAirport(from: firstSegment, isOrigin: true)
        let destAirport = TravelokaJSON.flightAirport(from: lastSegment, isOrigin: false)
        let originCity = TravelokaJSON.firstString([
            bookingDetail["sourceCity"],
            originAirport["location"],
            flightDetail["originCity"],
        ])
        let destCity = TravelokaJSON.firstString([
            bookingDetail["destinationCity"],
            destAirport["location"],
            flightDetail["destinationCity"],
        ])
        let originCode = TravelokaJSON.firstString([
            originAirport["airportCode"],
            flightDetail["originAirportCode"],
        ])
        let destCode = TravelokaJSON.firstString([
            destAirport["airportCode"],
            flightDetail["destinationAirportCode"],
        ])
        if let title = PlaceLabel.route(from: originCity, to: destCity) {
            fields.title = title
        }
        fields.locationFrom = [originCity, originCode].compactMap { $0 }.joined(separator: " ")
        fields.locationTo = [destCity, destCode].compactMap { $0 }.joined(separator: " ")
        fields.locationFromAddress = airportAddress(
            name: TravelokaJSON.firstString([originAirport["airportName"], flightDetail["originAirportName"]]),
            terminal: TravelokaJSON.firstString([originAirport["terminalName"], flightDetail["originTerminal"]])
        )
        fields.locationToAddress = airportAddress(
            name: TravelokaJSON.firstString([destAirport["airportName"], flightDetail["destinationAirportName"]]),
            terminal: TravelokaJSON.firstString([destAirport["terminalName"], flightDetail["destinationTerminal"]])
        )
        if let beginTZ = context.tzBegin {
            if let start = TravelokaJSON.dateFromApplied(firstSegment["departureDateTime"], timeZone: beginTZ) {
                fields.start = start
            }
            fields.flightDepartureOffsetSeconds = beginTZ.secondsFromGMT(for: fields.start)
        }
        if let endTZ = context.tzEnd {
            if let end = TravelokaJSON.dateFromApplied(lastSegment["arrivalDateTime"], timeZone: endTZ) {
                fields.end = end
            }
            fields.flightArrivalOffsetSeconds = endTZ.secondsFromGMT(for: fields.end)
        }
        fields.rateDetails = BookingRateDetails(
            airline: TravelokaJSON.string(fromKeys: ["airlineName", "brandName"], in: firstSegment)
                ?? TravelokaJSON.string(flightDetail["airlineName"]),
            passengerCount: flightPassengerCount(from: bookingDetail)
                ?? TravelokaJSON.int(flightDetail["passengerCount"]),
            baggageInfoRaw: flightBaggage(from: firstSegment, flightDetail: flightDetail)
        )
        fields.passengers = flightPassengers(
            bookingDetail: bookingDetail,
            eTicket: eTicket,
            flightDetail: flightDetail
        )
        fields.deadlines = flightDeadlines(
            flightDetail: flightDetail,
            ticketInfo: ticketInfo,
            bookingDetail: bookingDetail,
            timeZone: context.tzBegin
        )
        return fields
    }

    private static func namedPassengers(
        contact: [String: Any]?,
        fallbackName: String?
    ) -> [BookingPassenger] {
        if let contact, let passenger = passenger(from: contact, type: contactTravellerType(contact)) {
            return [passenger]
        }
        guard let fallbackName else { return [] }
        return [BookingPassenger(passengerNumber: 1, travellerType: .unknown, givenName: fallbackName)]
    }

    private static func contactTravellerType(_ contact: [String: Any]) -> TravellerType {
        TravellerType.parse(
            TravelokaJSON.string(contact["type"] ?? contact["passengerType"] ?? contact["typeDescription"])
        )
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
        let type = experienceTravellerType(from: experienceDetail)
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

    private static func experienceTravellerType(from detail: [String: Any]) -> TravellerType {
        if let infos = detail["travelersInfo"] as? [[String: Any]] {
            for info in infos {
                let parsed = TravellerType.parse(
                    TravelokaJSON.string(info["entranceTypeId"])
                        ?? TravelokaJSON.string(info["entranceTypeTitle"])
                )
                if parsed != .unknown { return parsed }
            }
        }
        if let barcodes = detail["barCodeInfos"] as? [[String: Any]] {
            for code in barcodes {
                let parsed = TravellerType.parse(TravelokaJSON.string(code["experiencePaxType"]))
                if parsed != .unknown { return parsed }
            }
        }
        return TravellerType.parse(TravelokaJSON.string(detail["selectedTicketDisplay"]))
    }

    private static func nameFromInfoList(_ list: [[String: Any]]?) -> String? {
        guard let list else { return nil }
        for item in list where TravelokaJSON.string(item["id"]) == "name" {
            return TravelokaJSON.string(item["label"])
        }
        return nil
    }

    private static func flightPassengers(
        bookingDetail: [String: Any],
        eTicket: [String: Any],
        flightDetail: [String: Any]
    ) -> [BookingPassenger] {
        if let mapped = flightPassengers(fromList: eTicket["passengers"] as? [[String: Any]]), !mapped.isEmpty {
            return mapped
        }
        let grouped = TravelokaJSON.dictionary(bookingDetail["passengers"])
        var combined: [(item: [String: Any], type: TravellerType)] = []
        for item in grouped["adults"] as? [[String: Any]] ?? [] {
            combined.append((item, .adult))
        }
        for item in grouped["children"] as? [[String: Any]] ?? [] {
            combined.append((item, .child))
        }
        for item in grouped["infants"] as? [[String: Any]] ?? [] {
            combined.append((item, .infant))
        }
        if !combined.isEmpty {
            return combined.enumerated().compactMap { index, pair in
                passenger(fromFlightItem: pair.item, number: index + 1, defaultType: pair.type)
            }
        }
        return flightPassengers(fromList: (flightDetail["passengers"] as? [[String: Any]])
            ?? (flightDetail["passengerList"] as? [[String: Any]]))
            ?? []
    }

    private static func flightPassengers(fromList list: [[String: Any]]?) -> [BookingPassenger]? {
        guard let list, !list.isEmpty else { return nil }
        let mapped = list.enumerated().compactMap { index, item in
            passenger(fromFlightItem: item, number: index + 1, defaultType: .unknown)
        }
        return mapped.isEmpty ? nil : mapped
    }

    private static func passenger(
        fromFlightItem item: [String: Any],
        number: Int,
        defaultType: TravellerType
    ) -> BookingPassenger? {
        let given = TravelokaJSON.string(item["firstName"] ?? item["givenName"])
        let family = TravelokaJSON.string(item["lastName"] ?? item["familyName"])
        let full = TravelokaJSON.string(item["name"] ?? item["passengerName"] ?? item["fullName"])
        if given == nil && family == nil && full == nil { return nil }
        let rawType = TravelokaJSON.string(
            item["type"] ?? item["passengerType"] ?? item["typeDescription"]
        )
        let type = rawType != nil ? TravellerType.parse(rawType) : defaultType
        if given != nil || family != nil {
            return BookingPassenger(
                passengerNumber: number,
                travellerType: type,
                givenName: given,
                familyName: family
            )
        }
        return BookingPassenger(
            passengerNumber: number,
            travellerType: type,
            givenName: full
        )
    }

    private static func flightPassengerCount(from bookingDetail: [String: Any]) -> Int? {
        let grouped = TravelokaJSON.dictionary(bookingDetail["passengers"])
        let adults = (grouped["adults"] as? [Any])?.count ?? 0
        let children = (grouped["children"] as? [Any])?.count ?? 0
        let infants = (grouped["infants"] as? [Any])?.count ?? 0
        let total = adults + children + infants
        return total > 0 ? total : nil
    }

    private static func flightBaggage(from segment: [String: Any], flightDetail: [String: Any]) -> String? {
        var parts: [String] = []
        let facilities = segment["facilities"] as? [[String: Any]] ?? []
        for facility in facilities {
            let type = TravelokaJSON.string(facility["type"])?.lowercased()
            let text = TravelokaJSON.string(facility["displayText"])
            switch type {
            case "cabinbaggage":
                if let text { parts.append("Cabin \(text)") }
            case "baggage":
                if let text { parts.append("Checked \(text)") }
            default:
                continue
            }
        }
        if parts.isEmpty {
            let cabin = TravelokaJSON.string(flightDetail["cabinBaggage"])
            let checked = TravelokaJSON.string(flightDetail["checkedBaggage"])
            parts = [cabin.map { "Cabin \($0)" }, checked.map { "Checked \($0)" }].compactMap { $0 }
        }
        return parts.isEmpty ? nil : parts.joined(separator: "; ")
    }

    private static func airportAddress(name: String?, terminal: String?) -> String? {
        TravelokaJSON.string(
            [name, terminal.map { $0.localizedCaseInsensitiveContains("terminal") ? $0 : "Terminal \($0)" }]
                .compactMap { $0 }
                .joined(separator: ", ")
        )
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
        let policies = TravelokaJSON.strings(detail["cancellationPolicies"])
        for policy in policies {
            if let days = firstInt(in: policy),
               isExperienceFreeCancellationPolicy(policy),
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

    private static func isExperienceFreeCancellationPolicy(_ policy: String) -> Bool {
        policy.localizedCaseInsensitiveContains("prior")
            || policy.localizedCaseInsensitiveContains("sebelum")
    }

    private static func vehicleTitle(name: String?, routeName: String?) -> String? {
        guard let name else { return nil }
        guard let routeName, !name.localizedCaseInsensitiveContains(routeName) else {
            return name
        }
        return "\(name) - \(routeName)"
    }

    private static func hotelDeadlines(
        from detail: [String: Any],
        localeInfo: [String: Any],
        bookingHotel: [String: Any],
        timeZone: TimeZone
    ) -> [CancellationDeadline] {
        let fromInfos = hotelDeadlinesFromPolicyInfos(
            bookingHotel["cancellationPolicyInfos"] ?? detail["cancellationPolicyInfos"],
            timeZone: timeZone
        )
        let fromPolicies = hotelDeadlinesFromPolicies(
            detail["cancellationPolicies"],
            timeZone: timeZone
        )
        return [fromInfos, fromPolicies].first(where: { !$0.isEmpty })
            ?? hotelDeadlinesFromPolicyText(
                TravelokaJSON.string(fromKeys: [
                    "roomCancelationPolicy",
                    "roomCancelationPolicyLabel",
                ], in: [localeInfo, bookingHotel]),
                timeZone: timeZone
            )
    }

    private static func hotelDeadlinesFromPolicyInfos(
        _ infosValue: Any?,
        timeZone: TimeZone
    ) -> [CancellationDeadline] {
        let infos = infosValue as? [[String: Any]] ?? []
        var result: [CancellationDeadline] = []
        for info in infos {
            let policyDetail = TravelokaJSON.dictionary(info["policyInfoDetail"])
            guard let type = TravelokaJSON.string(policyDetail["type"])?.uppercased() else { continue }
            let policyText = TravelokaJSON.string(info["appliedDateInfoDescription"])
                ?? TravelokaJSON.string(policyDetail["description"])
            let feeAmount = TravelokaJSON.moneyAmount(from: TravelokaJSON.dictionary(policyDetail["fee"]))
            switch type {
            case "FREE_CANCELLATION", "FREE":
                guard let date = TravelokaJSON.dateFromApplied(info["appliedEndDate"], timeZone: timeZone)
                    ?? TravelokaJSON.dateFromApplied(info["appliedStartDate"], timeZone: timeZone)
                else { continue }
                result.append(
                    TravelokaCancellationDeadlines.at(
                        date,
                        timeZone: timeZone,
                        policyText: policyText ?? "Free cancellation",
                        isFreeCancellation: true
                    )
                )
            case "FULL_CHARGE", "FEE":
                guard let date = TravelokaJSON.dateFromApplied(info["appliedStartDate"], timeZone: timeZone)
                    ?? TravelokaJSON.dateFromApplied(info["appliedEndDate"], timeZone: timeZone)
                else { continue }
                result.append(
                    TravelokaCancellationDeadlines.at(
                        date,
                        timeZone: timeZone,
                        policyText: policyText ?? "Cancellation fee",
                        isFreeCancellation: false,
                        feeAmount: feeAmount
                    )
                )
            default:
                continue
            }
        }
        return result
    }

    private static func hotelDeadlinesFromPolicies(
        _ policiesValue: Any?,
        timeZone: TimeZone
    ) -> [CancellationDeadline] {
        let policies = policiesValue as? [[String: Any]] ?? []
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

    private static let hotelFreeBeforeRegex = try? NSRegularExpression(
        pattern: #"Free Cancellation before\s+(\d{1,2}-[A-Za-z]{3}-\d{4}\s+\d{1,2}:\d{2})"#,
        options: [.caseInsensitive]
    )

    private static func hotelDeadlinesFromPolicyText(
        _ text: String?,
        timeZone: TimeZone
    ) -> [CancellationDeadline] {
        guard let text,
              let regex = hotelFreeBeforeRegex,
              let match = regex.firstMatch(
                in: text,
                range: NSRange(location: 0, length: (text as NSString).length)
              ),
              match.numberOfRanges >= 2
        else {
            return []
        }
        let raw = (text as NSString).substring(with: match.range(at: 1))
        guard let date = TravelokaJSON.localDateTime(raw, timeZone: timeZone) else {
            return []
        }
        return [
            TravelokaCancellationDeadlines.at(
                date,
                timeZone: timeZone,
                policyText: text,
                isFreeCancellation: true
            ),
        ]
    }

    private static func vehicleDeadlines(
        from detail: [String: Any],
        pickupAt: Date,
        timeZone: TimeZone
    ) -> [CancellationDeadline] {
        if let freeUntil = TravelokaJSON.string(detail["freeCancellationDeadlineLocal"]),
           let deadline = TravelokaCancellationDeadlines.free(local: freeUntil, timeZone: timeZone)
        {
            return [deadline]
        }
        let nested = TravelokaJSON.dictionary(detail["withoutDriverDetailInfo"])
        let refundTexts =
            TravelokaJSON.strings(detail["refundInfo"])
            + [TravelokaJSON.string(detail["policyInfo"])].compactMap { $0 }
            + TravelokaJSON.strings(nested["refundInfo"])
        let joined = refundTexts.joined(separator: " ").lowercased()
        guard isVehicle24HourFreeCancellation(joined) else {
            return []
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        guard let deadlineAt = calendar.date(byAdding: .hour, value: -24, to: pickupAt) else {
            return []
        }
        return [
            TravelokaCancellationDeadlines.at(
                deadlineAt,
                timeZone: timeZone,
                policyText: "Free cancellation until 24 hours before pick-up",
                isFreeCancellation: true
            ),
        ]
    }

    private static let vehicle24HourFreeCancellationMarkers = [
        "24 hours before",
        "more than 24 hours",
        "24 jam sebelum",
        "lebih dari 24 jam",
    ]

    private static func isVehicle24HourFreeCancellation(_ text: String) -> Bool {
        vehicle24HourFreeCancellationMarkers.contains { text.contains($0) }
    }

    private static func transmissionLabel(fromDetail detail: String?) -> String? {
        guard let detail else { return nil }
        let label = detail.split(separator: "•", maxSplits: 1).first.map(String.init)
        return TravelokaJSON.string(label)
    }

    private static func flightDeadlines(
        flightDetail: [String: Any],
        ticketInfo: [String: Any],
        bookingDetail: [String: Any],
        timeZone: TimeZone?
    ) -> [CancellationDeadline] {
        let buttonInfo = TravelokaJSON.dictionary(ticketInfo["eTicketButtonInfo"])
        if TravelokaJSON.bool(buttonInfo["buttonRefundAvailable"]) == false {
            return []
        }
        if TravelokaJSON.bool(flightDetail["refundable"]) == false {
            return []
        }
        if let label = TravelokaJSON.string(flightDetail["refundPolicyLabel"]),
           label.localizedCaseInsensitiveContains("non-refundable")
        {
            return []
        }
        let refundStatus = TravelokaJSON.string(
            TravelokaJSON.dictionary(bookingDetail["refundInfo"])["refundableStatus"]
        )?.uppercased()
        if refundStatus == "NO" || refundStatus == "NON_REFUNDABLE" {
            return []
        }
        // Fee-Refund: nur mit echter Deadline + Fee aus API (keine Free-Deadline erfinden).
        guard let fee = TravelokaJSON.double(flightDetail["refundFeeAmount"]),
              let local = TravelokaJSON.string(flightDetail["refundDeadlineLocal"]),
              let tz = timeZone,
              let deadline = TravelokaCancellationDeadlines.fee(
                  local: local,
                  timeZone: tz,
                  policyText: TravelokaJSON.string(flightDetail["refundPolicyLabel"]) ?? "Refund with fee",
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
