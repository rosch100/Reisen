import Foundation

private struct FailableDecodable<T: Decodable>: Decodable {
    let value: T?

    init(from decoder: Decoder) throws {
        value = try? T(from: decoder)
    }
}

private extension KeyedDecodingContainer {
    func decodeLossyArray<T: Decodable>(forKey key: Key) -> [T] {
        (try? decode([FailableDecodable<T>].self, forKey: key))?.compactMap(\.value) ?? []
    }

    func decodeLossy<T: Decodable>(_ type: T.Type, forKey key: Key) -> T? {
        try? decode(type, forKey: key)
    }
}

struct AirbnbStayHintEnvelope: Decodable {
    let scheduledEvent: AirbnbStayHintScheduledEvent

    enum CodingKeys: String, CodingKey {
        case scheduledEvent = "scheduled_event"
    }
}

struct AirbnbStayHintScheduledEvent: Decodable {
    let rows: [AirbnbStayHintRow]

    enum CodingKeys: String, CodingKey {
        case rows
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        rows = container.decodeLossyArray(forKey: .rows)
    }
}

struct AirbnbStayHintRow: Decodable {
    let id: String
    let title: String?
    let previewText: String?
    let destination: AirbnbStayHintDestination?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case previewText = "preview_text"
        case destination
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        previewText = try container.decodeIfPresent(String.self, forKey: .previewText)
        destination = container.decodeLossy(AirbnbStayHintDestination.self, forKey: .destination)
    }

    var visibleFragments: [String] {
        visibleParts([previewText]) + (destination?.visibleStrings ?? [])
    }

    var houseRuleItems: [AirbnbStayHintRuleItem] {
        destination?.houseRulesSection?.allItems ?? []
    }
}

struct AirbnbStayHintDestination: Decodable {
    let houseRulesSection: AirbnbStayHintHouseRulesSection?
    let houseManualSection: AirbnbStayHintHouseManualSection?

    enum CodingKeys: String, CodingKey {
        case houseRulesSection = "house_rules_section"
        case houseManualSection = "house_manual_section"
    }

    var visibleStrings: [String] {
        (houseRulesSection?.visibleStrings ?? []) + (houseManualSection?.visibleStrings ?? [])
    }
}

struct AirbnbStayHintHouseRulesSection: Decodable {
    let houseRulesTitle: String?
    let houseRulesSubtitle: String?
    let houseRulesSections: [AirbnbStayHintRulesGroup]

    enum CodingKeys: String, CodingKey {
        case houseRulesTitle = "house_rules_title"
        case houseRulesSubtitle = "house_rules_subtitle"
        case houseRulesSections = "house_rules_sections"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        houseRulesTitle = try container.decodeIfPresent(String.self, forKey: .houseRulesTitle)
        houseRulesSubtitle = try container.decodeIfPresent(String.self, forKey: .houseRulesSubtitle)
        houseRulesSections = container.decodeLossyArray(forKey: .houseRulesSections)
    }

    var visibleStrings: [String] {
        visibleParts([houseRulesTitle, houseRulesSubtitle])
            + houseRulesSections.flatMap(\.visibleStrings)
    }

    var allItems: [AirbnbStayHintRuleItem] {
        houseRulesSections.flatMap(\.items)
    }
}

struct AirbnbStayHintRulesGroup: Decodable {
    let title: String?
    let items: [AirbnbStayHintRuleItem]

    enum CodingKeys: String, CodingKey {
        case title
        case items
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        items = container.decodeLossyArray(forKey: .items)
    }

    var visibleStrings: [String] {
        visibleParts([title]) + items.flatMap(\.visibleStrings)
    }
}

struct AirbnbStayHintRuleItem: Decodable {
    let title: String?
    let subtitle: String?
    let text: String?

    var visibleStrings: [String] {
        visibleParts([title, subtitle, text])
    }

    var displayText: String {
        visibleStrings.joined(separator: " ")
    }
}

struct AirbnbStayHintHouseManualSection: Decodable {
    let title: String?
    let houseManual: String?

    enum CodingKeys: String, CodingKey {
        case title
        case houseManual = "house_manual"
    }

    var visibleStrings: [String] {
        visibleParts([title, houseManual])
    }
}

private func visibleParts(_ texts: [String?]) -> [String] {
    texts.compactMap { $0 }.map(collapsedVisible).filter { !$0.isEmpty }
}

private func collapsedVisible(_ text: String) -> String {
    text.split { $0.isWhitespace }.joined(separator: " ")
}
