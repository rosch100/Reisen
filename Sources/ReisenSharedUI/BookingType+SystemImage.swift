import ReisenDomain

/// SF Symbol für Picker, Listen und Detail-Typzeilen (HIG-SSOT, UI-Schicht).
public extension BookingType {
    var systemImageName: String {
        switch self {
        case .flight: return "airplane"
        case .hotel: return "bed.double.fill"
        case .ferry: return "ferry.fill"
        case .train: return "train.side.front.car"
        case .activity: return "ticket.fill"
        case .carRental: return "car.fill"
        case .other: return "ellipsis.circle"
        }
    }
}
