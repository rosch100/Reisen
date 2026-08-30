import Foundation
import Testing
import ReisenDomain

private let germanLocale = Locale(identifier: "de")

@Test func bookingType_activity_rawValueAndLabel() {
    L10n.withLocale(germanLocale) {

    #expect(BookingType.activity.rawValue == "activity")
    #expect(BookingType.activity.displayLabel == L10n.string(.bookingTypeActivity))
    #expect(BookingType.allCases.contains(.activity))
    }
}

@Test func bookingType_carRental_rawValueAndLabel() {
    L10n.withLocale(germanLocale) {

    #expect(BookingType.carRental.rawValue == "carRental")
    #expect(BookingType.carRental.displayLabel == L10n.string(.bookingTypeCarRental))
    #expect(BookingType.allCases.contains(.carRental))
    }
}

@Test func bookingType_train_rawValueAndLabel() {
    L10n.withLocale(germanLocale) {

    #expect(BookingType.train.rawValue == "train")
    #expect(BookingType.train.displayLabel == L10n.string(.bookingTypeTrain))
    #expect(BookingType.allCases.contains(.train))
    let ferryIndex = BookingType.allCases.firstIndex(of: .ferry)
    let trainIndex = BookingType.allCases.firstIndex(of: .train)
    let activityIndex = BookingType.allCases.firstIndex(of: .activity)
    #expect(ferryIndex != nil)
    #expect(trainIndex != nil)
    #expect(activityIndex != nil)
    #expect(ferryIndex! < trainIndex!)
    #expect(trainIndex! < activityIndex!)
    }
}

@Test func bookingType_usesFlightLikeSchedule() {
    #expect(BookingType.flight.usesFlightLikeSchedule)
    #expect(BookingType.ferry.usesFlightLikeSchedule)
    #expect(BookingType.train.usesFlightLikeSchedule)
    #expect(!BookingType.hotel.usesFlightLikeSchedule)
    #expect(!BookingType.activity.usesFlightLikeSchedule)
    #expect(!BookingType.carRental.usesFlightLikeSchedule)
    #expect(!BookingType.other.usesFlightLikeSchedule)
}

@Test func bookingType_detailFieldLabels_train() {
    L10n.withLocale(germanLocale) {

    #expect(BookingType.train.showsLocationFrom == true)
    #expect(BookingType.train.locationFromLabel == L10n.string(.bookingFieldLocationFromTrain))
    #expect(BookingType.train.locationToLabel == L10n.string(.bookingFieldLocationToTrain))
    #expect(BookingType.train.locationFromAddressLabel == L10n.string(.bookingFieldLocationFromAddressTrain))
    #expect(BookingType.train.locationToAddressLabel == L10n.string(.bookingFieldLocationToAddressTrain))
    #expect(BookingType.train.roomCategoryLabel == L10n.string(.bookingFieldRoomCategoryTrain))
    #expect(BookingType.train.roomCountLabel == nil)
    #expect(BookingType.train.scheduleStartLabel == L10n.string(.bookingFieldScheduleStartTrain))
    #expect(BookingType.train.scheduleEndLabel == L10n.string(.bookingFieldScheduleEndTrain))
    #expect(BookingType.train.operatorNameLabel == L10n.string(.bookingFieldOperatorTrain))
    #expect(BookingType.train.showsOperatorNameField)
    #expect(!BookingType.hotel.showsOperatorNameField)
    #expect(!BookingType.flight.showsOperatorNameField)
    #expect(BookingType.activity.showsOperatorNameField)
    #expect(BookingType.carRental.showsOperatorNameField)
    #expect(!BookingType.ferry.showsOperatorNameField)
    #expect(!BookingType.other.showsOperatorNameField)
    #expect(BookingType.train.persistsOperatorName)
    #expect(BookingType.activity.persistsOperatorName)
    #expect(BookingType.carRental.persistsOperatorName)
    #expect(BookingType.ferry.persistsOperatorName)
    #expect(BookingType.other.persistsOperatorName)
    #expect(!BookingType.flight.persistsOperatorName)
    #expect(!BookingType.hotel.persistsOperatorName)
    #expect(BookingType.flight.supportsFlightOffsetAutofill)
    #expect(BookingType.ferry.supportsFlightOffsetAutofill)
    #expect(!BookingType.train.supportsFlightOffsetAutofill)
    }
}

@Test func bookingStatus_displayLabels() {
    L10n.withLocale(germanLocale) {

    #expect(BookingStatus.confirmed.displayLabel == L10n.string(.bookingStatusConfirmed))
    #expect(BookingStatus.cancelled.displayLabel == L10n.string(.bookingStatusCancelled))
    #expect(BookingStatus.unknown.displayLabel == L10n.string(.bookingStatusUnknown))
    }
}

@Test func bookingType_detailFieldLabels_hotel() {
    L10n.withLocale(germanLocale) {

    #expect(BookingType.hotel.showsLocationFrom == false)
    #expect(BookingType.hotel.locationToLabel == L10n.string(.bookingFieldLocationToHotel))
    #expect(BookingType.hotel.locationToAddressLabel == L10n.string(.bookingFieldLocationToAddressHotel))
    #expect(BookingType.hotel.roomCategoryLabel == L10n.string(.bookingFieldRoomCategoryHotel))
    #expect(BookingType.hotel.roomCountLabel == L10n.string(.bookingFieldRoomCountHotel))
    #expect(BookingType.hotel.scheduleStartLabel == L10n.string(.bookingFieldScheduleStartHotel))
    #expect(BookingType.hotel.scheduleEndLabel == L10n.string(.bookingFieldScheduleEndHotel))
    #expect(BookingType.hotel.operatorNameLabel == L10n.string(.bookingFieldOperatorDefault))
    }
}

@Test func bookingType_detailFieldLabels_carRental() {
    L10n.withLocale(germanLocale) {

    #expect(BookingType.carRental.showsLocationFrom == true)
    #expect(BookingType.carRental.locationFromLabel == L10n.string(.bookingFieldLocationFromCarRental))
    #expect(BookingType.carRental.locationToLabel == L10n.string(.bookingFieldLocationToCarRental))
    #expect(BookingType.carRental.locationFromAddressLabel == L10n.string(.bookingFieldLocationFromAddressCarRental))
    #expect(BookingType.carRental.locationToAddressLabel == L10n.string(.bookingFieldLocationToAddressCarRental))
    #expect(BookingType.carRental.roomCategoryLabel == L10n.string(.bookingFieldRoomCategoryCarRental))
    #expect(BookingType.carRental.roomCountLabel == nil)
    #expect(BookingType.carRental.scheduleStartLabel == L10n.string(.bookingFieldScheduleStartCarRental))
    #expect(BookingType.carRental.scheduleEndLabel == L10n.string(.bookingFieldScheduleEndCarRental))
    #expect(BookingType.carRental.operatorNameLabel == L10n.string(.bookingFieldOperatorCarRental))
    }
}

@Test func bookingType_detailFieldLabels_activity() {
    L10n.withLocale(germanLocale) {

    #expect(BookingType.activity.roomCategoryLabel == L10n.string(.bookingFieldRoomCategoryActivity))
    #expect(BookingType.activity.locationToAddressLabel == L10n.string(.bookingFieldLocationToAddressActivity))
    #expect(BookingType.activity.scheduleStartLabel == L10n.string(.bookingFieldScheduleStartEvent))
    #expect(BookingType.activity.operatorNameLabel == L10n.string(.bookingFieldOperatorActivity))
    }
}

@Test func bookingType_detailFieldLabels_flight() {
    L10n.withLocale(germanLocale) {

    #expect(BookingType.flight.locationFromLabel == L10n.string(.bookingFieldLocationFromFlight))
    #expect(BookingType.flight.locationToLabel == L10n.string(.bookingFieldLocationToFlight))
    #expect(BookingType.flight.locationFromAddressLabel == L10n.string(.bookingFieldLocationFromAddressFlight))
    #expect(BookingType.flight.locationToAddressLabel == L10n.string(.bookingFieldLocationToAddressFlight))
    #expect(BookingType.flight.scheduleStartLabel == L10n.string(.bookingFieldScheduleStartFlight))
    #expect(BookingType.flight.scheduleEndLabel == L10n.string(.bookingFieldScheduleEndFlight))
    }
}

@Test func bookingType_detailFieldLabels_ferry() {
    L10n.withLocale(germanLocale) {

    #expect(BookingType.ferry.locationFromLabel == L10n.string(.bookingFieldLocationFromFerry))
    #expect(BookingType.ferry.locationToLabel == L10n.string(.bookingFieldLocationToFlight))
    #expect(BookingType.ferry.scheduleStartLabel == L10n.string(.bookingFieldScheduleStartFerry))
    }
}

@Test func bookingDetailLabels_yesNo() {
    L10n.withLocale(germanLocale) {

    #expect(BookingDetailLabels.yesNo(true) == L10n.string(.commonYes))
    #expect(BookingDetailLabels.yesNo(false) == L10n.string(.commonNo))
    }
}
