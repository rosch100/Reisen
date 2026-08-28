import Foundation
import Testing
import ReisenAirbnb
import ReisenDomain

@Test("AirbnbGuestHintParser mappt sichtbare Stay-Detail-Phrasen aus house_rules")
func airbnbGuestHintParserParsesVisibleStayDetailPhrases() throws {
    let hints = AirbnbGuestHintParser().parse(from: try researchStayHintsJSON())
    let keys = Set(hints.map(\.sourceKey))
    #expect(keys.contains { $0.hasPrefix("airbnb:house_rules:prep") })
    #expect(!keys.contains("airbnb:house_manual:prep"))
    #expect(!keys.contains("airbnb:amenity:essentials:absent"))
    let towels = try #require(
        hints.first {
            $0.detail.localizedCaseInsensitiveContains("Handtücher selbst mitbringen")
                || $0.title.localizedCaseInsensitiveContains("Handtücher")
        }
    )
    #expect(towels.detail.localizedCaseInsensitiveContains("Handtücher selbst mitbringen"))
    let linens = try #require(hints.first { $0.title.localizedCaseInsensitiveContains("Bettwäsche") })
    #expect(linens.detail.localizedCaseInsensitiveContains("keine Wäsche"))
    #expect(hints.count >= 2)
}

@Test("AirbnbGuestHintParser liefert leer ohne prep-relevante Stay-Detail-Phrasen")
func airbnbGuestHintParserIgnoresStayDetailWithoutPrepPhrases() {
    let hints = parseStayHints(
        """
        {
          "id": "house_rules",
          "title": "Hausregeln",
          "preview_text": "Höchstens 2 Gäste. Haustiere erlaubt. Ruhezeiten: 22:00 - 07:00.",
          "destination": {
            "house_rules_section": {
              "house_rules_sections": [
                { "items": [ { "title": "Keine Partys oder Veranstaltungen" } ] }
              ]
            }
          }
        },
        {
          "id": "house_manual",
          "title": "Gäste-Handbuch",
          "preview_text": "Tea and cups are in the cabinet."
        }
        """
    )
    #expect(hints.isEmpty)
}

@Test("AirbnbGuestHintParser mappt Gäste-Handbuch nur bei prep-relevantem Text")
func airbnbGuestHintParserParsesHouseManualWhenPrepPhraseVisible() {
    let hints = parseStayHints(
        """
        {
          "id": "house_manual",
          "title": "Gäste-Handbuch",
          "preview_text": "Welcome.",
          "destination": {
            "house_manual_section": {
              "house_manual": "Please bring your own towels. Linens are not provided."
            }
          }
        }
        """
    )
    #expect(hints.map(\.sourceKey) == ["airbnb:house_manual:prep"])
    #expect(hints[0].title == "Gäste-Handbuch")
    #expect(hints[0].detail.localizedCaseInsensitiveContains("bring your own towels"))
}

@Test("AirbnbGuestHintParser stellt eigene Bettwäsche als eigene House-Rule dar")
func airbnbGuestHintParserMapsOwnLinensHouseRuleItem() {
    let hints = parseStayHints(
        """
        {
          "id": "house_rules",
          "title": "Hausregeln",
          "preview_text": "Höchstens 2 Gäste. Ruhezeiten: 22:00 - 07:00.",
          "destination": {
            "house_rules_section": {
              "house_rules_sections": [
                {
                  "title": "Während deines Aufenthalts",
                  "items": [
                    { "title": "Ruhezeiten", "subtitle": "22:00 - 07:00" },
                    {
                      "title": "Eigene Bettwäsche erforderlich",
                      "subtitle": "Es liegt keine Wäsche bereit."
                    }
                  ]
                }
              ]
            }
          }
        }
        """
    )
    let linens = hints.first { $0.title.localizedCaseInsensitiveContains("Bettwäsche") }
    #expect(linens != nil)
    #expect(linens?.sourceKey.contains("house_rules") == true)
    #expect(linens?.detail.localizedCaseInsensitiveContains("keine Wäsche") == true)
    #expect(hints.contains { $0.title == "Ruhezeiten" } == false)
}

@Test("AirbnbGuestHintParser behält mehrere besondere House-Rules nebeneinander")
func airbnbGuestHintParserKeepsMultipleSpecialHouseRuleItems() {
    let hints = parseStayHints(houseRulesItems: """
        { "title": "Handtücher selbst mitbringen" },
        { "title": "Eigene Bettwäsche", "subtitle": "Bitte Laken selbst mitbringen." }
        """)
    let titles = Set(hints.map(\.title))
    #expect(titles.contains("Handtücher selbst mitbringen"))
    #expect(titles.contains("Eigene Bettwäsche"))
    #expect(hints.count == 2)
}

@Test("AirbnbGuestHintParser unterscheidet gleiche Titel mit verschiedenem Detail")
func airbnbGuestHintParserKeepsSameTitleDifferentDetail() {
    let hints = parseStayHints(houseRulesItems: """
        { "title": "Zusätzliche Regeln", "subtitle": "Handtücher selbst mitbringen." },
        { "title": "Zusätzliche Regeln", "subtitle": "Bettwäsche selbst mitbringen." }
        """)
    #expect(hints.count == 2)
    #expect(Set(hints.map(\.sourceKey)).count == 2)
    #expect(hints.contains { $0.detail.localizedCaseInsensitiveContains("Handtücher") })
    #expect(hints.contains { $0.detail.localizedCaseInsensitiveContains("Bettwäsche") })
}

@Test("AirbnbGuestHintParser unterscheidet gleiche Titel trotz langem gemeinsamen Detail-Präfix")
func airbnbGuestHintParserKeepsSameTitleWhenDetailDiffersAfterPrefix() {
    let shared = String(repeating: "Handtücher selbst mitbringen. Bitte extra einpacken. ", count: 4)
    let hints = parseStayHints(houseRulesItems: """
        { "title": "Zusätzliche Regeln", "subtitle": "\(shared)Variante A — nur für die Anreise." },
        { "title": "Zusätzliche Regeln", "subtitle": "\(shared)Variante B — nur für die Abreise." }
        """)
    #expect(hints.count == 2)
    #expect(Set(hints.map(\.sourceKey)).count == 2)
    #expect(hints.contains { $0.detail.contains("Variante A") })
    #expect(hints.contains { $0.detail.contains("Variante B") })
}

@Test("AirbnbGuestHintParser zeigt Prep-Phrase aus langem Gäste-Handbuch, nicht nur den Textanfang")
func airbnbGuestHintParserExcerptsHouseManualAroundPrepPhrase() {
    let padding = String(repeating: "Im Schrank stehen Tassen und Tee. ", count: 12)
    let hints = parseStayHints(
        """
        {
          "id": "house_manual",
          "title": "Gäste-Handbuch",
          "destination": {
            "house_manual_section": {
              "house_manual": "\(padding)Please bring your own towels."
            }
          }
        }
        """
    )
    #expect(hints.count == 1)
    #expect(hints[0].detail.localizedCaseInsensitiveContains("bring your own towels"))
    #expect(hints[0].detail.count <= 280)
}

@Test("AirbnbGuestHintParser behält gültige Rows wenn eine destination nicht zum Schema passt")
func airbnbGuestHintParserSkipsMalformedDestinationWithoutDroppingSiblings() throws {
    let hints = parseStayHints(
        """
        {
          "id": "house_rules",
          "title": "Hausregeln",
          "destination": {
            "house_rules_section": {
              "house_rules_sections": [
                { "items": { "not": "an-array" } }
              ]
            }
          }
        },
        {
          "id": "house_manual",
          "title": "Gäste-Handbuch",
          "destination": {
            "house_manual_section": {
              "house_manual": "Please bring your own towels."
            }
          }
        }
        """
    )
    #expect(hints.map(\.sourceKey) == ["airbnb:house_manual:prep"])
    let hint = try #require(hints.first)
    #expect(hint.detail.localizedCaseInsensitiveContains("bring your own towels"))
}

@Test("AirbnbGuestHintParser behält gültige House-Rule-Gruppen wenn items einer Gruppe nicht zum Schema passt")
func airbnbGuestHintParserKeepsSiblingHouseRuleGroupsWhenOneItemsPayloadIsMalformed() throws {
    let hints = parseStayHints(
        """
        {
          "id": "house_rules",
          "title": "Hausregeln",
          "destination": {
            "house_rules_section": {
              "house_rules_sections": [
                { "items": { "not": "an-array" } },
                {
                  "items": [
                    {
                      "title": "Eigene Bettwäsche",
                      "subtitle": "Bitte Laken selbst mitbringen."
                    }
                  ]
                }
              ]
            }
          }
        }
        """
    )
    #expect(hints.count == 1)
    let linens = try #require(hints.first)
    #expect(linens.title.localizedCaseInsensitiveContains("Bettwäsche"))
    #expect(linens.detail.localizedCaseInsensitiveContains("Laken selbst mitbringen"))
}

@Test("AirbnbGuestHintParser ignoriert Stay-RO ohne Regeln-Zeilen")
func airbnbGuestHintParserIgnoresStaySampleWithoutRulesRows() throws {
    let json = try TestFixtures.text("scheduled_events_stay_sample.json")
    let hints = AirbnbGuestHintParser().parse(from: json)
    #expect(hints.isEmpty)
}

private func parseStayHints(_ rowsJSON: String) -> [BookingGuestHint] {
    AirbnbGuestHintParser().parse(
        from: """
        { "scheduled_event": { "rows": [ \(rowsJSON) ] } }
        """
    )
}

private func parseStayHints(houseRulesItems itemsJSON: String) -> [BookingGuestHint] {
    parseStayHints(
        """
        {
          "id": "house_rules",
          "title": "Hausregeln",
          "destination": {
            "house_rules_section": {
              "house_rules_sections": [ { "items": [ \(itemsJSON) ] } ]
            }
          }
        }
        """
    )
}

private func researchStayHintsJSON() throws -> String {
    let url = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("docs/fixtures/provider-research/airbnb_stay_hints_synthetic.json")
    return try String(contentsOf: url, encoding: .utf8)
}
