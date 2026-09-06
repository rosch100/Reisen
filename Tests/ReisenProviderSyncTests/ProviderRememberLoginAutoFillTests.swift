import Testing
@testable import ReisenProviderSync

@Test func rememberLoginAutoFill_usesUsernameNotEmailAddress() {
    #expect(ProviderRememberLoginAutoFill.usernameContentType == .username)
    #expect(ProviderRememberLoginAutoFill.usernameContentType != .emailAddress)
}

@Test func rememberLoginAutoFill_usesPasswordNotNewPassword() {
    #expect(ProviderRememberLoginAutoFill.passwordContentType == .password)
    #expect(ProviderRememberLoginAutoFill.passwordContentType != .newPassword)
}
