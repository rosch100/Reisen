import Foundation
import ReisenDomain

/// Parst Mietwagen-Detailseiten (`mietwagen.check24.de`, `CpInitial` in Page-HTML).
public enum Check24CarRentalDetailParser {
    static let cpInitialKey = "\"CpInitial\""

    /// Catalog- und `enrichBooking`-Wait auf eingebettetes Portal-Payload.
    static let detailReadyJavaScript = """
        (() => {
          const html = document.documentElement.outerHTML;
          return html.includes('\(cpInitialKey)') && html.includes('rentalcarDetails');
        })()
        """

    public static func parse(from html: String) -> ParsedCarRentalDetail? {
        guard let json = HotelBasketJSONScan.extractTopLevelJSONObject(
            from: html,
            after: cpInitialKey
        ) else {
            return nil
        }
        guard let data = json.data(using: .utf8) else { return nil }
        do {
            let dto = try JSONDecoder().decode(Check24CarRentalCpInitialDTO.self, from: data)
            return detail(from: dto, html: html)
        } catch {
            // Schema-Drift / unerwartetes CpInitial: kein Partial-Mapping, Aufrufer behandelt nil.
            return nil
        }
    }

    private static func detail(
        from dto: Check24CarRentalCpInitialDTO,
        html: String
    ) -> ParsedCarRentalDetail {
        let places = places(from: dto)
        let price = priceFields(from: dto.rentalcarDetails)
        return ParsedCarRentalDetail(
            title: vehicleTitle(from: dto.rentalcarDetails, html: html),
            operatorName: operatorName(from: dto, html: html),
            confirmationCode: NonEmpty.string(dto.bookingNumber),
            locationFrom: places.nameFrom,
            locationTo: places.nameTo,
            locationFromAddress: places.addressFrom,
            locationToAddress: places.addressTo,
            totalPriceAmount: price.amount,
            totalPriceCurrency: price.currency,
            vehicleCategory: NonEmpty.string(dto.rentalcarDetails?.categoryName)
        )
    }
}
