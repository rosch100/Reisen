import Foundation
import ReisenDomain

extension DomainMapper {
    public static func gap(from model: SDGap) -> Gap {
        Gap(
            id: model.id,
            tripID: model.trip?.id,
            fromBookingID: model.fromBooking?.id,
            toBookingID: model.toBooking?.id,
            gapStart: model.gapStart,
            gapEnd: model.gapEnd,
            kind: GapKind(rawValue: model.kindRaw) ?? .both,
            titleOverride: model.titleOverride,
            identityKey: model.identityKey,
            priceAmount: model.priceAmount,
            priceCurrencyCode: model.priceCurrencyCode,
            suggestionStateRaw: model.suggestionStateRaw
        )
    }

    public static func reminder(from model: SDReminder) -> Reminder {
        Reminder(
            id: model.id,
            fireAt: model.fireAt,
            target: ReminderTarget(rawValue: model.targetRaw) ?? .custom,
            channel: ReminderChannel(rawValue: model.channelRaw) ?? .notification,
            status: ReminderStatus(rawValue: model.statusRaw) ?? .scheduled,
            title: model.title,
            notes: model.notes,
            cancellationDeadlineID: model.cancellationDeadlineID,
            gapID: model.gapID,
            externalAlarmId: model.externalAlarmId
        )
    }
}
