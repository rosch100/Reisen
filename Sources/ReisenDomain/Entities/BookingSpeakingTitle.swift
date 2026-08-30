import Foundation

/// Sprechender Buchungstitel analog Provider-Importen (`PlaceLabel.route`, Hotel-/Ereignisname).
public enum BookingSpeakingTitle {
    public static func make(
        bookingType: BookingType,
        title: String?,
        locationFrom: String?,
        locationTo: String?,
        operatorName: String?
    ) -> String? {
        if bookingType.usesFlightLikeSchedule {
            return PlaceLabel.route(from: locationFrom, to: locationTo)
                ?? NonEmpty.first(locationTo, locationFrom, title)
        }
        if bookingType == .carRental {
            return NonEmpty.first(
                title,
                PlaceLabel.route(from: locationFrom, to: locationTo),
                operatorName
            )
        }
        return NonEmpty.first(title, operatorName)
    }
}
