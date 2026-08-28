import SwiftUI
import ReisenDomain

/// SSOT: Buchungstyp mit SF Symbol und lokalem Label (Picker, Listen, Details).
public struct BookingTypeLabel: View {
    let bookingType: BookingType
    var font: Font = .caption

    public init(_ bookingType: BookingType, font: Font = .caption) {
        self.bookingType = bookingType
        self.font = font
    }

    public var body: some View {
        Label {
            Text(bookingType.displayLabel)
                .font(font)
        } icon: {
            Image(systemName: bookingType.systemImageName)
                .imageScale(.small)
        }
        .labelStyle(.titleAndIcon)
    }
}
