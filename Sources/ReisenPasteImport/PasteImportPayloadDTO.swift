import Foundation

/// Modell-Antwort eines Paste-Import-Laufs: mehrere Buchungen aus einer Quelle.
public struct PasteImportPayloadDTO: Equatable, Sendable, Codable {
    public var bookings: [PasteImportBookingDTO]

    public init(bookings: [PasteImportBookingDTO] = []) {
        self.bookings = bookings
    }
}

/// Transportformat einer `PasteImportExtraction`: Daten als ISO8601-Strings, Enums als rawValue-Strings.
///
/// Bewusst ohne Domain-Typen, damit Task 8 `@Generable` auf diesen Typen legen kann.
public struct PasteImportBookingDTO: Equatable, Sendable, Codable {
    public var bookingType: String?
    public var startAtISO8601: String?
    public var endAtISO8601: String?
    public var title: String?
    public var confirmationCode: String?
    public var externalUrl: String?
    public var locationFrom: String?
    public var locationTo: String?
    public var locationFromAddress: String?
    public var locationToAddress: String?
    public var operatorName: String?
    public var status: String?
    public var hotelCheckInMinutes: Int?
    public var hotelCheckOutMinutes: Int?
    public var hotelOffsetSeconds: Int?
    public var flightDepartureOffsetSeconds: Int?
    public var flightArrivalOffsetSeconds: Int?
    public var passengers: [PasteImportPassengerDTO]
    public var guestHints: [PasteImportGuestHintDTO]
    public var rateDetails: PasteImportRateDetailsDTO?
    public var deadlines: [PasteImportDeadlineDTO]

    public init(
        bookingType: String? = nil,
        startAtISO8601: String? = nil,
        endAtISO8601: String? = nil,
        title: String? = nil,
        confirmationCode: String? = nil,
        externalUrl: String? = nil,
        locationFrom: String? = nil,
        locationTo: String? = nil,
        locationFromAddress: String? = nil,
        locationToAddress: String? = nil,
        operatorName: String? = nil,
        status: String? = nil,
        hotelCheckInMinutes: Int? = nil,
        hotelCheckOutMinutes: Int? = nil,
        hotelOffsetSeconds: Int? = nil,
        flightDepartureOffsetSeconds: Int? = nil,
        flightArrivalOffsetSeconds: Int? = nil,
        passengers: [PasteImportPassengerDTO] = [],
        guestHints: [PasteImportGuestHintDTO] = [],
        rateDetails: PasteImportRateDetailsDTO? = nil,
        deadlines: [PasteImportDeadlineDTO] = []
    ) {
        self.bookingType = bookingType
        self.startAtISO8601 = startAtISO8601
        self.endAtISO8601 = endAtISO8601
        self.title = title
        self.confirmationCode = confirmationCode
        self.externalUrl = externalUrl
        self.locationFrom = locationFrom
        self.locationTo = locationTo
        self.locationFromAddress = locationFromAddress
        self.locationToAddress = locationToAddress
        self.operatorName = operatorName
        self.status = status
        self.hotelCheckInMinutes = hotelCheckInMinutes
        self.hotelCheckOutMinutes = hotelCheckOutMinutes
        self.hotelOffsetSeconds = hotelOffsetSeconds
        self.flightDepartureOffsetSeconds = flightDepartureOffsetSeconds
        self.flightArrivalOffsetSeconds = flightArrivalOffsetSeconds
        self.passengers = passengers
        self.guestHints = guestHints
        self.rateDetails = rateDetails
        self.deadlines = deadlines
    }
}

/// Zwilling zu `BookingPassenger`; `passengerNumber` fehlend heißt „Reihenfolge im Array“.
public struct PasteImportPassengerDTO: Equatable, Sendable, Codable {
    public var passengerNumber: Int?
    public var travellerType: String?
    public var title: String?
    public var givenName: String?
    public var familyName: String?
    public var secondFamilyName: String?
    public var birthDateISO8601: String?

    public init(
        passengerNumber: Int? = nil,
        travellerType: String? = nil,
        title: String? = nil,
        givenName: String? = nil,
        familyName: String? = nil,
        secondFamilyName: String? = nil,
        birthDateISO8601: String? = nil
    ) {
        self.passengerNumber = passengerNumber
        self.travellerType = travellerType
        self.title = title
        self.givenName = givenName
        self.familyName = familyName
        self.secondFamilyName = secondFamilyName
        self.birthDateISO8601 = birthDateISO8601
    }
}

/// Zwilling zu `BookingGuestHint`; `sourceKey` vergibt der Mapper inhaltsbasiert.
public struct PasteImportGuestHintDTO: Equatable, Sendable, Codable {
    public var title: String?
    public var detail: String?

    public init(title: String? = nil, detail: String? = nil) {
        self.title = title
        self.detail = detail
    }
}

/// Zwilling zu `BookingRateDetails` ohne Raum-Positionen (aus Freitext nicht verlässlich).
public struct PasteImportRateDetailsDTO: Equatable, Sendable, Codable {
    public var totalPriceAmount: Double?
    public var totalPriceCurrency: String?
    public var roomCategory: String?
    public var boardType: String?
    public var includedBreakfast: Bool?
    public var guestCount: Int?
    public var roomCount: Int?
    public var airline: String?
    public var passengerCount: Int?
    public var baggageInfoRaw: String?

    public init(
        totalPriceAmount: Double? = nil,
        totalPriceCurrency: String? = nil,
        roomCategory: String? = nil,
        boardType: String? = nil,
        includedBreakfast: Bool? = nil,
        guestCount: Int? = nil,
        roomCount: Int? = nil,
        airline: String? = nil,
        passengerCount: Int? = nil,
        baggageInfoRaw: String? = nil
    ) {
        self.totalPriceAmount = totalPriceAmount
        self.totalPriceCurrency = totalPriceCurrency
        self.roomCategory = roomCategory
        self.boardType = boardType
        self.includedBreakfast = includedBreakfast
        self.guestCount = guestCount
        self.roomCount = roomCount
        self.airline = airline
        self.passengerCount = passengerCount
        self.baggageInfoRaw = baggageInfoRaw
    }
}

/// Zwilling zu `CancellationDeadline`; ohne Datum ist die Frist unbrauchbar.
public struct PasteImportDeadlineDTO: Equatable, Sendable, Codable {
    public var deadlineAtISO8601: String?
    public var policyText: String?
    public var isFreeCancellation: Bool?
    public var cancellationFeeAmount: Double?
    public var hotelOffsetSeconds: Int?

    public init(
        deadlineAtISO8601: String? = nil,
        policyText: String? = nil,
        isFreeCancellation: Bool? = nil,
        cancellationFeeAmount: Double? = nil,
        hotelOffsetSeconds: Int? = nil
    ) {
        self.deadlineAtISO8601 = deadlineAtISO8601
        self.policyText = policyText
        self.isFreeCancellation = isFreeCancellation
        self.cancellationFeeAmount = cancellationFeeAmount
        self.hotelOffsetSeconds = hotelOffsetSeconds
    }
}
