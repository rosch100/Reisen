import Foundation
import ReisenDomain

/// Öffentliche Anweisungen an das Foundation-Model. SSOT für Session und Tests.
public enum PasteImportExtractionInstructions {
    public static var text: String {
        """
        Du liest Reise-Bestätigungen aus E-Mail, PDF und Screenshot (Deutsch und Englisch).
        Gib nur zurück, was das Material belegt. Nichts ergänzen, nichts schätzen.

        - Unsichere Felder weglassen statt raten.
        - bookingType nur aus: \(labels(BookingType.allCases)). Tour, Event, GetYourGuide, Ausflug = activity (nicht hotel). Zug, Bahn, ICE, Trainline = train. Mietwagen, Sixt, Hertz = carRental.
        - status nur aus: \(labels(BookingStatus.allCases)). bestätigt/booked = confirmed.
        - travellerType nur aus: \(labels(TravellerType.allCases)).
        - boardType nur aus: \(labels(BookingBoardType.allCases)).
        - startAt und endAt sind Reisezeiten: Abfahrt, Ankunft, Check-in, Check-out, Pickup, Rückgabe, Tourstart. Nie das Buchungsdatum, nie das Zahlungsdatum.
        - Zeitpunkte als ISO8601. Zeitzone nur wenn das Material sie nennt (Z oder Offset). Sonst lokale Uhrzeit ohne Z, z. B. 2026-08-08T07:45:00.
        - confirmationCode = PNR, Booking reference, Auftragsnummer oder Reservierungsnummer. Der Wert neben dem Label, nicht das Label selbst (nicht „Booking reference“, nicht Initialen). Nicht der Preis. Nicht die 13-stellige Ticketnummer, wenn ein 6-stelliger PNR dasteht.
        - Steht Abfahrt, Departure Date, Check-in oder Pickup im Material, muss startAt gesetzt sein (Datum reicht, Uhrzeit 00:00 wenn keine Uhr da ist).
        - Die Beispiele zeigen nur das Format. Werte ausschließlich aus dem aktuellen Material. Keine Codes, Orte oder Zeiten aus den Beispielen übernehmen.
        - Jedes Flugsegment mit eigener Abflugzeit wird ein eigener Eintrag; derselbe PNR darf mehrfach vorkommen.
        - AGB, Fare Rules, Important Notes, Baggage policy, Catatan Penting ignorieren.
        - Jede Buchung im Material wird ein eigener Eintrag in bookings.

        \(PasteImportExtractionExamples.asInstructionBlock)
        """
    }

    private static func labels<Label: RawRepresentable>(_ cases: [Label]) -> String
    where Label.RawValue == String {
        cases.map(\.rawValue).joined(separator: ", ")
    }
}

/// Kanonische DE/EN-Beispiele (fiktive Daten). Die Anweisung zitiert genau dieses Material.
public enum PasteImportExtractionExamples {
    public struct Sample: Sendable {
        public var name: String
        public var material: String
        public var expected: [PasteImportBookingDTO]
    }

    public static let all: [Sample] = [
        Sample(
            name: "flight-en",
            material: """
                Booking Reference (PNR): EXAM01
                Flight LH 400
                Frankfurt (FRA) 28 Aug 2026 10:00
                New York (JFK) 28 Aug 2026 13:05
                Passenger: ADA LOVELACE
                Status: Confirmed
                """,
            expected: [
                PasteImportBookingDTO(
                    bookingType: "flight",
                    startAtISO8601: "2026-08-28T10:00:00",
                    endAtISO8601: "2026-08-28T13:05:00",
                    title: "LH 400",
                    confirmationCode: "EXAM01",
                    locationFrom: "FRA",
                    locationTo: "JFK",
                    operatorName: "Lufthansa",
                    status: "confirmed"
                )
            ]
        ),
        Sample(
            name: "flight-de-connect",
            material: """
                Anschlussflug-Bestätigung
                Buchungscode: EXAM02
                Frankfurt (FRA) Fr. 12. Jun. 2026 09:10 → Doha (DOH)
                Doha (DOH) → Singapur (SIN) Fr. 12. Jun. 2026 19:55
                Frau Ada Beispiel
                """,
            expected: [
                PasteImportBookingDTO(
                    bookingType: "flight",
                    startAtISO8601: "2026-06-12T09:10:00",
                    title: "FRA–DOH",
                    confirmationCode: "EXAM02",
                    locationFrom: "FRA",
                    locationTo: "DOH",
                    operatorName: "Beispiel-Airline",
                    status: "confirmed"
                ),
                PasteImportBookingDTO(
                    bookingType: "flight",
                    startAtISO8601: "2026-06-12T19:55:00",
                    title: "DOH–SIN",
                    confirmationCode: "EXAM02",
                    locationFrom: "DOH",
                    locationTo: "SIN",
                    operatorName: "Beispiel-Airline",
                    status: "confirmed"
                )
            ]
        ),
        Sample(
            name: "flight-lcc",
            material: """
                Booking Reference (PNR): EXAM0A
                Flight Depart Arrive
                XY 101 Sample City Origin Sample City Dest
                (AAA) (BBB)
                21 Aug 2026 21 Aug 2026
                17:05 hrs 18:25 hrs
                Operated by Sample Air
                """,
            expected: [
                PasteImportBookingDTO(
                    bookingType: "flight",
                    startAtISO8601: "2026-08-21T17:05:00",
                    endAtISO8601: "2026-08-21T18:25:00",
                    title: "XY 101",
                    confirmationCode: "EXAM0A",
                    locationFrom: "AAA",
                    locationTo: "BBB",
                    operatorName: "Sample Air",
                    status: "confirmed"
                )
            ]
        ),
        Sample(
            name: "train-de",
            material: """
                Ihre Buchung bei der Deutschen Bahn
                Auftragsnummer: EXAM03
                ICE 512
                Berlin Hbf ab 28.08.2026 09:02
                München Hbf an 28.08.2026 13:16
                """,
            expected: [
                PasteImportBookingDTO(
                    bookingType: "train",
                    startAtISO8601: "2026-08-28T09:02:00",
                    endAtISO8601: "2026-08-28T13:16:00",
                    title: "ICE 512",
                    confirmationCode: "EXAM03",
                    locationFrom: "Berlin Hbf",
                    locationTo: "München Hbf",
                    operatorName: "Deutsche Bahn",
                    status: "confirmed"
                )
            ]
        ),
        Sample(
            name: "train-en",
            material: """
                Trainline booking confirmation
                Booking reference: EXAM04
                London Paddington 28 Aug 2026 08:15
                Bristol Temple Meads 28 Aug 2026 09:40
                """,
            expected: [
                PasteImportBookingDTO(
                    bookingType: "train",
                    startAtISO8601: "2026-08-28T08:15:00",
                    endAtISO8601: "2026-08-28T09:40:00",
                    title: "Paddington–Bristol",
                    confirmationCode: "EXAM04",
                    locationFrom: "London Paddington",
                    locationTo: "Bristol Temple Meads",
                    operatorName: "Trainline",
                    status: "confirmed"
                )
            ]
        ),
        Sample(
            name: "hotel-en",
            material: """
                CONFIRMATION NUMBER: EXAM05
                Hotel Deloix
                CHECK-IN Thursday 20 August 2026 from 14:00
                CHECK-OUT Wednesday 26 August 2026 until 12:00
                Address: Avenida Severo Ochoa 34, Benidorm
                """,
            expected: [
                PasteImportBookingDTO(
                    bookingType: "hotel",
                    startAtISO8601: "2026-08-20T14:00:00",
                    endAtISO8601: "2026-08-26T12:00:00",
                    title: "Hotel Deloix",
                    confirmationCode: "EXAM05",
                    locationTo: "Benidorm",
                    locationToAddress: "Avenida Severo Ochoa 34, Benidorm",
                    operatorName: "Hotel Deloix",
                    status: "confirmed",
                    hotelCheckInMinutes: 840,
                    hotelCheckOutMinutes: 720
                )
            ]
        ),
        Sample(
            name: "hotel-de",
            material: """
                Buchungsbestätigung
                Buchungsnummer: EXAM06
                Pension Lindenhof, Heidelberg
                Anreise: 03.09.2026 ab 15:00
                Abreise: 07.09.2026 bis 11:00
                """,
            expected: [
                PasteImportBookingDTO(
                    bookingType: "hotel",
                    startAtISO8601: "2026-09-03T15:00:00",
                    endAtISO8601: "2026-09-07T11:00:00",
                    title: "Pension Lindenhof",
                    confirmationCode: "EXAM06",
                    locationTo: "Heidelberg",
                    operatorName: "Pension Lindenhof",
                    status: "confirmed",
                    hotelCheckInMinutes: 900,
                    hotelCheckOutMinutes: 660
                )
            ]
        ),
        Sample(
            name: "car-de",
            material: """
                Sixt Buchungsbestätigung
                Reservierungsnummer: EXAM07
                Abholung: München Flughafen, 28.08.2026 10:00
                Rückgabe: München Flughafen, 01.09.2026 10:00
                Fahrzeugklasse: Economy
                """,
            expected: [
                PasteImportBookingDTO(
                    bookingType: "carRental",
                    startAtISO8601: "2026-08-28T10:00:00",
                    endAtISO8601: "2026-09-01T10:00:00",
                    title: "Economy München Flughafen",
                    confirmationCode: "EXAM07",
                    locationFrom: "München Flughafen",
                    locationTo: "München Flughafen",
                    operatorName: "Sixt",
                    status: "confirmed"
                )
            ]
        ),
        Sample(
            name: "car-en",
            material: """
                Hertz booking confirmation
                Reservation number: EXAM08
                Pick-up: Heathrow Terminal 2, 28 Aug 2026 11:00
                Drop-off: Heathrow Terminal 2, 2 Sep 2026 11:00
                Car type: Compact
                """,
            expected: [
                PasteImportBookingDTO(
                    bookingType: "carRental",
                    startAtISO8601: "2026-08-28T11:00:00",
                    endAtISO8601: "2026-09-02T11:00:00",
                    title: "Compact Heathrow",
                    confirmationCode: "EXAM08",
                    locationFrom: "Heathrow Terminal 2",
                    locationTo: "Heathrow Terminal 2",
                    operatorName: "Hertz",
                    status: "confirmed"
                )
            ]
        ),
        Sample(
            name: "activity-en",
            material: """
                GetYourGuide booking confirmation
                Booking reference: EXAM09
                Colosseum Guided Tour
                Date: 28 August 2026
                Start time: 09:30
                Meeting point: Piazza del Colosseo
                """,
            expected: [
                PasteImportBookingDTO(
                    bookingType: "activity",
                    startAtISO8601: "2026-08-28T09:30:00",
                    title: "Colosseum Guided Tour",
                    confirmationCode: "EXAM09",
                    locationTo: "Piazza del Colosseo",
                    operatorName: "GetYourGuide",
                    status: "confirmed"
                )
            ]
        ),
        Sample(
            name: "activity-de-tour",
            material: """
                Komodo Tour Indonesia Eticket
                Name: Ada Lovelace
                Booking Date: 14 July 2026
                Departure Date: 15 August 2026
                Tour Duration: 4D3N Trip LBJ Elona
                TOTAL: 25.200.000
                """,
            expected: [
                PasteImportBookingDTO(
                    bookingType: "activity",
                    startAtISO8601: "2026-08-15T00:00:00",
                    title: "4D3N Trip LBJ Elona",
                    locationTo: "Labuan Bajo",
                    operatorName: "Komodo Tour Indonesia",
                    status: "confirmed"
                )
            ]
        ),
        Sample(
            name: "flight-tk-ref",
            material: """
                Sample City - Other City
                EXAM0C
                Booking reference
                1. Flight
                Sample City (AAA) Other City (BBB) 12 June Friday 2027 Economy
                09:10
                """,
            expected: [
                PasteImportBookingDTO(
                    bookingType: "flight",
                    startAtISO8601: "2027-06-12T09:10:00",
                    title: "AAA–BBB",
                    confirmationCode: "EXAM0C",
                    locationFrom: "AAA",
                    locationTo: "BBB",
                    status: "confirmed"
                )
            ]
        ),
        Sample(
            name: "flight-screenshot-de",
            material: """
                Beispielstadt nach Zielstadt
                Planmäßig
                Beispielstadt
                AAA
                09:10
                Fr., 12. Jun. 2027
                Terminal 1
                1 Stopp
                Erwachsener
                Ms Ada Beispiel
                Zielstadt
                BBB
                19:55
                Fr., 12. Jun. 2027
                """,
            expected: [
                PasteImportBookingDTO(
                    bookingType: "flight",
                    startAtISO8601: "2027-06-12T09:10:00",
                    endAtISO8601: "2027-06-12T19:55:00",
                    title: "AAA–BBB",
                    locationFrom: "AAA",
                    locationTo: "BBB",
                    status: "confirmed"
                )
            ]
        ),
        Sample(
            name: "hotel-airbnb",
            material: """
                Your reservation is confirmed
                Confirmation code: EXAM0D
                Loft near the canal
                Check-in: 3 Sep 2027 after 15:00
                Checkout: 7 Sep 2027 before 11:00
                Amsterdam
                """,
            expected: [
                PasteImportBookingDTO(
                    bookingType: "hotel",
                    startAtISO8601: "2027-09-03T15:00:00",
                    endAtISO8601: "2027-09-07T11:00:00",
                    title: "Loft near the canal",
                    confirmationCode: "EXAM0D",
                    locationTo: "Amsterdam",
                    operatorName: "Airbnb",
                    status: "confirmed",
                    hotelCheckInMinutes: 900,
                    hotelCheckOutMinutes: 660
                )
            ]
        ),
        Sample(
            name: "activity-eventbrite",
            material: """
                Order confirmation
                Order #EXAM0E
                Jazz Night
                Event date: Friday, 12 June 2027
                Doors 19:00
                Venue: Sample Hall, Berlin
                """,
            expected: [
                PasteImportBookingDTO(
                    bookingType: "activity",
                    startAtISO8601: "2027-06-12T19:00:00",
                    title: "Jazz Night",
                    confirmationCode: "EXAM0E",
                    locationTo: "Sample Hall, Berlin",
                    operatorName: "Eventbrite",
                    status: "confirmed"
                )
            ]
        ),
        Sample(
            name: "train-oebb",
            material: """
                ÖBB Buchungsbestätigung
                PNR: EXAM0F
                RJX 168
                Wien Hbf ab 12.06.2027 08:42
                Salzburg Hbf an 12.06.2027 11:02
                """,
            expected: [
                PasteImportBookingDTO(
                    bookingType: "train",
                    startAtISO8601: "2027-06-12T08:42:00",
                    endAtISO8601: "2027-06-12T11:02:00",
                    title: "RJX 168",
                    confirmationCode: "EXAM0F",
                    locationFrom: "Wien Hbf",
                    locationTo: "Salzburg Hbf",
                    operatorName: "ÖBB",
                    status: "confirmed"
                )
            ]
        ),
        Sample(
            name: "ferry-de",
            material: """
                Fährticket
                Buchungsnummer: EXAM0G
                Puttgarden ab 12.06.2027 13:30
                Rødby an 12.06.2027 14:15
                """,
            expected: [
                PasteImportBookingDTO(
                    bookingType: "ferry",
                    startAtISO8601: "2027-06-12T13:30:00",
                    endAtISO8601: "2027-06-12T14:15:00",
                    title: "Puttgarden–Rødby",
                    confirmationCode: "EXAM0G",
                    locationFrom: "Puttgarden",
                    locationTo: "Rødby",
                    status: "confirmed"
                )
            ]
        ),
    ]

    static var asInstructionBlock: String {
        all.map { sample in
            let fields = sample.expected.enumerated().map { index, dto in
                "Buchung \(index): bookingType=\(dto.bookingType ?? "-") "
                    + "startAtISO8601=\(dto.startAtISO8601 ?? "-") "
                    + "endAtISO8601=\(dto.endAtISO8601 ?? "-") "
                    + "confirmationCode=\(dto.confirmationCode ?? "-") "
                    + "title=\(dto.title ?? "-") "
                    + "from=\(dto.locationFrom ?? "-") to=\(dto.locationTo ?? "-")"
            }.joined(separator: "\n")
            return """
                Beispiel \(sample.name):
                \(sample.material)
                →
                \(fields)
                """
        }.joined(separator: "\n\n")
    }
}
