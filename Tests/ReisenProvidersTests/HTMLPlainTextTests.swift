import Foundation
import Testing
import ReisenProviders

@Test("HTMLPlainText flatten entfernt Script-i18n, nicht nur Tags")
func htmlPlainTextFlattenStripsScriptBodies() {
    let html = """
    <p>Handtücher enthalten.</p>
    <script>{"pet_fees":"Haustiere willkommen ohne sichtbaren Text"}</script>
    """
    let text = HTMLPlainText.flatten(html)
    #expect(text.contains("Handtücher enthalten"))
    #expect(!text.lowercased().contains("haustiere willkommen"))
}

@Test("HTMLPlainText flatten entfernt Style-Blöcke")
func htmlPlainTextFlattenStripsStyleBodies() {
    let html = "<p>WLAN</p><style>body{content:'Bettwäsche wird nicht'}</style>"
    let text = HTMLPlainText.flatten(html)
    #expect(text.contains("WLAN"))
    #expect(!text.lowercased().contains("bettwäsche wird nicht"))
}
