import Foundation
import Testing
import ReisenDomain
import ReisenPasteImport

@Test func pasteImportExtractionInstructions_listEveryBookingTypeAndStatus() {
    let text = PasteImportExtractionInstructions.text
    for type in BookingType.allCases {
        #expect(text.contains(type.rawValue), "Anweisung ohne bookingType \(type.rawValue)")
    }
    for status in BookingStatus.allCases {
        #expect(text.contains(status.rawValue), "Anweisung ohne status \(status.rawValue)")
    }
}

@Test func pasteImportExtractionInstructions_teachTravelDateNotPurchaseDateAndPNRNotPrice() {
    let text = PasteImportExtractionInstructions.text
    #expect(text.contains("startAt"))
    #expect(text.contains("Buchungsdatum") || text.contains("Booking Date"))
    #expect(text.contains("PNR") || text.contains("Auftragsnummer"))
    #expect(text.contains("activity"))
    #expect(text.contains("carRental"))
    #expect(text.contains("Keine Codes"))
    #expect(text.contains("nicht das Label"))
}

@Test func pasteImportExtractionExamples_coverFlightTrainHotelCarActivityInGermanAndEnglish() {
    let names = Set(PasteImportExtractionExamples.all.map(\.name))
    #expect(names.contains("flight-en"))
    #expect(names.contains("flight-de-connect"))
    #expect(names.contains("flight-lcc"))
    #expect(names.contains("train-de"))
    #expect(names.contains("train-en"))
    #expect(names.contains("hotel-en"))
    #expect(names.contains("hotel-de"))
    #expect(names.contains("car-de"))
    #expect(names.contains("car-en"))
    #expect(names.contains("activity-en"))
    #expect(names.contains("activity-de-tour"))
    #expect(names.contains("flight-tk-ref"))
    #expect(names.contains("flight-screenshot-de"))
    #expect(names.contains("hotel-airbnb"))
    #expect(names.contains("activity-eventbrite"))
    #expect(names.contains("train-oebb"))
    #expect(names.contains("ferry-de"))
}

@Test func pasteImportExtractionExamples_mapThroughFilterAsCandidates() throws {
    for sample in PasteImportExtractionExamples.all {
        #expect(!sample.expected.isEmpty, "Beispiel \(sample.name) ohne erwartete Buchung")
        for dto in sample.expected {
            let extraction = PasteImportGenerableMapper.extraction(from: dto)
            let draft = try #require(
                PasteImportFilter.apply([extraction]).first,
                "Beispiel \(sample.name) braucht bookingType und startAt"
            )
            #expect(draft.bookingType == extraction.bookingType)
            if draft.bookingType.usesFlightLikeSchedule,
               let route = PlaceLabel.route(from: draft.locationFrom, to: draft.locationTo)
            {
                #expect(draft.title == route, "Beispiel \(sample.name) braucht sprechenden Routentitel")
            }
        }
    }
}

@Test func pasteImportExtractionInstructions_embedEveryExampleMaterial() {
    let text = PasteImportExtractionInstructions.text
    for sample in PasteImportExtractionExamples.all {
        #expect(text.contains(sample.material), "Anweisung ohne Material \(sample.name)")
    }
}
