import Foundation
import ReisenDomain

/// Geparste Mietwagen-Detailfelder aus Check24 Kundenportal (`CpInitial` + data-qa).
public struct ParsedCarRentalDetail: Equatable, Sendable {
    public let title: String?
    public let operatorName: String?
    public let confirmationCode: String?
    public let locationFrom: String?
    public let locationTo: String?
    public let locationFromAddress: String?
    public let locationToAddress: String?
    public let totalPriceAmount: Double?
    public let totalPriceCurrency: String?
    public let vehicleCategory: String?

    public init(
        title: String? = nil,
        operatorName: String? = nil,
        confirmationCode: String? = nil,
        locationFrom: String? = nil,
        locationTo: String? = nil,
        locationFromAddress: String? = nil,
        locationToAddress: String? = nil,
        totalPriceAmount: Double? = nil,
        totalPriceCurrency: String? = nil,
        vehicleCategory: String? = nil
    ) {
        self.title = title
        self.operatorName = operatorName
        self.confirmationCode = confirmationCode
        self.locationFrom = locationFrom
        self.locationTo = locationTo
        self.locationFromAddress = locationFromAddress
        self.locationToAddress = locationToAddress
        self.totalPriceAmount = totalPriceAmount
        self.totalPriceCurrency = totalPriceCurrency
        self.vehicleCategory = vehicleCategory
    }

    /// Preis/Fahrzeugklasse für Draft/Enrich (`roomCategory` = Fahrzeugklasse).
    public var rateDetails: BookingRateDetails? {
        guard totalPriceAmount != nil || vehicleCategory != nil else { return nil }
        return BookingRateDetails(
            totalPriceAmount: totalPriceAmount,
            totalPriceCurrency: totalPriceCurrency,
            roomCategory: vehicleCategory,
            lastParsedAt: Date()
        )
    }

    /// Nicht-nil Detailfelder auf Katalog-/Enrich-Fakten legen (SSOT Mapping + Enrich).
    public func apply(to facts: inout ProviderBookingFacts) {
        if let title { facts.title = title }
        if let confirmationCode { facts.confirmationCode = confirmationCode }
        if let locationFrom { facts.locationFrom = locationFrom }
        if let locationTo { facts.locationTo = locationTo }
        if let locationFromAddress { facts.locationFromAddress = locationFromAddress }
        if let locationToAddress { facts.locationToAddress = locationToAddress }
        if let operatorName { facts.operatorName = operatorName }
        if let rateDetails {
            facts.rateDetails = BookingRateDetails.merging(
                existing: facts.rateDetails,
                incoming: rateDetails
            )
        }
    }
}
