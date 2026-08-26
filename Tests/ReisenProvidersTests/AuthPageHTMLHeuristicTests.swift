import Testing
import Foundation
import ReisenProviders

@Test("AuthPageHTMLHeuristic: Check24 Login-HTML")
func authPageHTMLHeuristicCheck24() {
    let loginHTML = """
    <html><body>
    <form action="https://kundenbereich.check24.de/user/login.html">
    <input type="password" name="password">
    </form>
    </body></html>
    """
    #expect(AuthPageHTMLHeuristic.check24LooksLikeLoginHTML(loginHTML))
    #expect(!AuthPageHTMLHeuristic.check24LooksLikeLoginHTML(#"{ "activities": [] }"#))
}

@Test("AuthPageHTMLHeuristic: Opodo Login-HTML")
func authPageHTMLHeuristicOpodo() {
    let loginHTML = """
    <html><body>
    <form action="https://www.opodo.de/user/login">
    <input type="password" name="password">
    </form>
    </body></html>
    """
    #expect(AuthPageHTMLHeuristic.opodoLooksLikeLoginHTML(loginHTML))
    #expect(!AuthPageHTMLHeuristic.opodoLooksLikeLoginHTML(
        "<html><body><a href=\"https://www.opodo.de/travel/secure/\">Trips</a></body></html>",
        responseURL: URL(string: "https://www.opodo.de/travel/secure/")
    ))
}
