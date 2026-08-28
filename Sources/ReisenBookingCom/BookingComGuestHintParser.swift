import Foundation
import ReisenDomain
import ReisenProviders

/// Extracts prep-relevant hints from Booking.com confirmation HTML.
public struct BookingComGuestHintParser: Sendable {
    public init() {}

    public func parse(from html: String) -> [BookingGuestHint] {
        StayHintHTMLExtractor.extract(
            from: html,
            providerRaw: ProviderID.booking.rawValue,
            matching: Self.arrivalAndCheckIn,
            firstMatching: Self.pets
        )
    }

    private typealias Pattern = StayHintHTMLExtractor.HintPattern

    private static let arrivalAndCheckIn: [Pattern] = [
        Pattern(
            "ankunftszeit im voraus",
            "time of arrival in advance",
            title: "Ankunftszeit",
            detail: "Ankunftszeit im Voraus an die Unterkunft mitteilen.",
            key: "arrival:in_advance"
        ),
        Pattern(
            "lichtbildausweis",
            "photo id and credit",
            "photo identification and credit",
            title: "Check-in",
            detail: "Beim Check-in Lichtbildausweis und Kreditkarte vorlegen.",
            key: "checkin:photo_id"
        ),
    ]

    private static let pets: [Pattern] = [
        Pattern(
            "haustiere sind nicht erlaubt",
            "haustiere nicht erlaubt",
            "haustiere sind nicht gestattet",
            "pets are not allowed",
            "pets not allowed",
            "no pets allowed",
            title: "Haustiere",
            detail: "Haustiere sind in dieser Unterkunft nicht erlaubt.",
            key: "pets:not_allowed"
        ),
        Pattern(
            "haustiere willkommen",
            "haustiere sind erlaubt",
            "pets are welcome",
            title: "Haustiere",
            detail: "Haustiere sind in dieser Unterkunft erlaubt.",
            key: "pets:allowed"
        ),
    ]
}
