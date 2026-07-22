import Foundation

public struct Trip: Identifiable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var startDate: Date
    public var endDate: Date
    public var destination: String?
    public var notes: String?
    public var bookingIDs: [UUID]

    public init(
        id: UUID = UUID(),
        title: String,
        startDate: Date,
        endDate: Date,
        destination: String? = nil,
        notes: String? = nil,
        bookingIDs: [UUID] = []
    ) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.destination = destination
        self.notes = notes
        self.bookingIDs = bookingIDs
    }
}
