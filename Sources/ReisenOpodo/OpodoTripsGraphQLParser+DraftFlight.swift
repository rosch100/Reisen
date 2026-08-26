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
        let from = cityWithIata(city: fromCity, iata: fromIata)
        let to = cityWithIata(city: toCity, iata: toIata)

        let title: String? = {
            if let fromCity, let toCity {
                return "\(fromCity) → \(toCity)"
            }
            return toCity ?? fromCity
        }()

        let pnr = sections.compactMap(\.pnr).first
        let airline = firstSection?.carrier?.name
        let passengerCount = trip.travellers.flatMap { $0.isEmpty ? nil : $0.count }

        var details = rateDetails
        if var existing = details {
            existing.airline = airline
            existing.passengerCount = passengerCount
            details = existing
        } else if airline != nil || passengerCount != nil {
            details = BookingRateDetails(airline: airline, passengerCount: passengerCount)
        }

        return ProviderBookingDraft(
            provider: .opodo,
            bookingType: .flight,
            title: title,
            confirmationCode: pnr ?? trip.id,
            externalUrl: externalUrl,
            startAt: startAt,
            endAt: endAt,
            locationFrom: from,
            locationTo: to,
            locationFromAddress: nonEmpty(firstSection?.departure?.name),
            locationToAddress: nonEmpty(firstSection?.arrival?.name),
            status: status(bookingStatus: trip.bookingStatus, productStatus: trip.bookingProductStatus),
            rateDetails: details
        )
    }
}
