import Testing
import Foundation
import ReisenProviders

@Test func opodoSessionProbeAppliesToOpodoHosts() {
    #expect(OpodoSessionProbe.applies(to: URL(string: "https://www.opodo.de/")!))
    #expect(OpodoSessionProbe.applies(to: URL(string: "https://www.opodo.de/travel/secure/")!))
    #expect(OpodoSessionProbe.applies(to: URL(string: "https://opodo.de/")!))
    #expect(!OpodoSessionProbe.applies(to: URL(string: "https://kundenbereich.check24.de/")!))
}

@Test func opodoSessionProbeParsesLoggedInTrue() {
    let json = #"{"data":{"userAccount":{"isLoggedIn":true,"email":"a@b.de"}}}"#
    #expect(OpodoSessionProbe.isLoggedIn(fromGraphQLJSON: json) == true)
}

@Test func opodoSessionProbeParsesLoggedInFalse() {
    let json = #"{"data":{"userAccount":{"isLoggedIn":false,"email":null}}}"#
    #expect(OpodoSessionProbe.isLoggedIn(fromGraphQLJSON: json) == false)
}

@Test func opodoSessionProbeRequestBodyContainsGetUserAccount() {
    let body = String(data: OpodoSessionProbe.getUserAccountRequestBody(), encoding: .utf8) ?? ""
    #expect(body.contains("GetUserAccount"))
    #expect(body.contains("isLoggedIn"))
}
