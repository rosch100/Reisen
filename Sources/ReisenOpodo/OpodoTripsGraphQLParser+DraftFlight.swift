import Foundation
import ReisenDomain

extension OpodoTripsGraphQLParser {
    func draftFlight(
        trip: OpodoGraphQLTrip,
        itinerary: OpodoGraphQLItinerary,
        externalUrl: String,
        rateDetails: BookingRateDetails?
    ) -> ProviderBookingDraft? {
        guard let startAt = dateFromEpochMillis(itinerary.departureDate),
              let endAt = dateFromEpochMillis(itinerary.arrivalDate) else {
            return nil
        }

        let fromCity = itinerary.origin?.cityName
        let toCity = itinerary.destination?.cityName
        let sections = itinerary.legs?
            .compactMap(\.sections)
            .flatMap { $0 } ?? []
        let firstSection = sections.first

        let fromIata = firstSection?.departure?.iata ?? itinerary.origin?.iata
        let toIata = firstSection?.arrival?.iata ?? itinerary.destination?.iata
        let from = PlaceLabel.make(city: fromCity, iata: fromIata?.uppercased())
        let to = PlaceLabel.make(city: toCity, iata: toIata?.uppercased())
        let title = PlaceLabel.route(from: fromCity, to: toCity)
            ?? NonEmpty.string(toCity)
            ?? NonEmpty.string(fromCity)

        let pnr = sections.compactMap(\.pnr).first
        let airline = firstSection?.carrier?.name
        let passengerCount = trip.travellers.flatMap { $0.isEmpty ? nil : $0.count }

        let incomingRates: BookingRateDetails? = {
            guard airline != nil || passengerCount != nil else { return nil }
            return BookingRateDetails(airline: airline, passengerCount: passengerCount)
        }()
        let details = BookingRateDetails.merging(existing: rateDetails, incoming: incomingRates)

        let times = TemporalFact.pair(bookingType: .flight, start: startAt, end: endAt)
        return DraftAssembler.draft(
            from: ProviderBookingFacts(
                provider: .opodo,
                bookingType: .flight,
                start: times.start,
                end: times.end,
                title: title,
                confirmationCode: pnr ?? trip.id,
                externalUrl: externalUrl,
                locationFrom: from,
                locationTo: to,
                locationFromAddress: NonEmpty.string(firstSection?.departure?.name),
                locationToAddress: NonEmpty.string(firstSection?.arrival?.name),
                statusRaw: BookingStatus.joinedRaw(trip.bookingStatus, trip.bookingProductStatus),
                rateDetails: details
            )
        )
    }
}
