import Foundation
import ReisenDomain

extension Check24CarRentalDetailParser {
    struct Places {
        let nameFrom: String?
        let nameTo: String?
        let addressFrom: String?
        let addressTo: String?
    }

    static func vehicleTitle(
        from details: Check24CarRentalCpInitialDTO.Details?,
        html: String
    ) -> String? {
        if let description = NonEmpty.string(details?.description) {
            if details?.isGuaranteedCarModel == false {
                return "\(description) oder ähnlich"
            }
            return description
        }
        return firstDataQA(html, id: "qa-rentalcar-name")
    }

    static func operatorName(
        from dto: Check24CarRentalCpInitialDTO,
        html: String
    ) -> String? {
        firstDataQA(html, id: "qa-renter-name")
            ?? NonEmpty.string(dto.cancel?.supplier)
    }

    static func places(from dto: Check24CarRentalCpInitialDTO) -> Places {
        let destinations = destinationTitles(from: dto.actions)
        let addresses = stationAddresses(from: dto.stations ?? [])
        let isOneWay = dto.vehicleHandovers?.isOneWay == true

        let pickup = endpoint(
            destinationTitle: destinations.pickup,
            handover: dto.vehicleHandovers?.pickup,
            station: addresses.first,
            fallback: nil
        )
        let dropoff = endpoint(
            destinationTitle: destinations.dropoff,
            handover: dto.vehicleHandovers?.dropoff,
            station: isOneWay ? addresses.last : nil,
            fallback: isOneWay ? nil : pickup
        )
        return Places(
            nameFrom: pickup.name,
            nameTo: dropoff.name,
            addressFrom: pickup.address,
            addressTo: dropoff.address
        )
    }

    static func priceFields(
        from details: Check24CarRentalCpInitialDTO.Details?
    ) -> (amount: Double?, currency: String?) {
        guard let priceRaw = NonEmpty.string(
            details?.price?.replacingOccurrences(of: "\u{00A0}", with: " ")
        ) else {
            return (nil, nil)
        }
        let amount = BookingDetailsParser().parseAmountText(
            priceRaw.replacingOccurrences(of: "€", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        )
        let currency: String? = priceRaw.contains("€") ? "EUR" : nil
        return (amount, currency)
    }

    static func destinationTitles(
        from actions: [Check24CarRentalCpInitialDTO.Action]?
    ) -> (pickup: String?, dropoff: String?) {
        guard let actions else { return (nil, nil) }
        for action in actions {
            guard let href = action.href,
                  let items = URLComponents(string: href)?.queryItems else { continue }
            let pickup = queryValue(items, Check24CarRentalJumpin.depTitle)
            let dropoff = queryValue(items, Check24CarRentalJumpin.destTitle)
            if pickup != nil || dropoff != nil {
                return (pickup, dropoff)
            }
        }
        return (nil, nil)
    }

    static func stationAddresses(
        from stations: [Check24CarRentalCpInitialDTO.Station]
    ) -> [(label: String?, address: String)] {
        stations.compactMap { station in
            let street = NonEmpty.string(station.street)
            let zipCity = NonEmpty.string(station.zipCity)
            guard street != nil || zipCity != nil else { return nil }
            let address = [street, zipCity].compactMap { $0 }.joined(separator: ", ")
            return (label: street, address: address)
        }
    }

    /// Extrahiert sichtbaren Text aus `data-qa-id="…">…</…>` (ohne verschachtelte Tags).
    static func firstDataQA(_ html: String, id: String) -> String? {
        let pattern = #"data-qa-id=\"\#(id)\">([^<]+)<"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let ns = html as NSString
        let range = NSRange(location: 0, length: ns.length)
        guard let match = regex.firstMatch(in: html, range: range),
              match.numberOfRanges >= 2 else { return nil }
        return NonEmpty.string(ns.substring(with: match.range(at: 1)))
    }

    private static func endpoint(
        destinationTitle: String?,
        handover: Check24CarRentalCpInitialDTO.HandoverPoint?,
        station: (label: String?, address: String)?,
        fallback: (name: String?, address: String?)?
    ) -> (name: String?, address: String?) {
        (
            name: NonEmpty.first(
                destinationTitle,
                handover?.name,
                station?.label,
                fallback?.name
            ),
            address: NonEmpty.first(
                handover?.address,
                station?.address,
                fallback?.address
            )
        )
    }

    private static func queryValue(_ items: [URLQueryItem], _ name: String) -> String? {
        NonEmpty.string(items.first { $0.name == name }?.value)
    }
}
