import Foundation
import Testing
import ReisenProviders

@Test func check24SessionProbeAppliesToCheck24Hosts() {
    #expect(Check24SessionProbe.applies(to: URL(string: "https://www.check24.de/")!))
    #expect(Check24SessionProbe.applies(to: URL(string: "https://kundenbereich.check24.de/user/login.html")!))
    #expect(Check24SessionProbe.applies(to: URL(string: "https://accounts.check24.com/login")!))
    #expect(Check24SessionProbe.applies(to: URL(string: "https://m.check24.de/kundenbereich/actions/all")!))
    #expect(!Check24SessionProbe.applies(to: URL(string: "https://www.opodo.de/")!))
}

@Test func check24SessionProbeDetectsActivitiesJSON() {
    #expect(Check24SessionProbe.isLoggedIn(fromActivitiesResponse: #"{"activities":[]}"#) == true)
    #expect(Check24SessionProbe.isLoggedIn(fromActivitiesResponse: #"{"activities":[{"id":1}]}"#) == true)
    #expect(
        Check24SessionProbe.isLoggedIn(
            fromActivitiesResponse: #"<html><form action="/user/login"><input type="password"></form></html>"#
        ) == false
    )
    #expect(Check24SessionProbe.isLoggedIn(fromActivitiesResponse: #"{"error":"unauthorized"}"#) == false)
    #expect(
        Check24SessionProbe.isLoggedIn(
            fromActivitiesResponse: #"<html><script>var x = "activities"</script></html>"#
        ) == false
    )
}
