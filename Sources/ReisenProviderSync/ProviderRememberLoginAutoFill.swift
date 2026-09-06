#if os(iOS)
import UIKit
#else
import AppKit
#endif

/// Apple Password AutoFill für native Felder im Dialog „Anmeldung merken“.
/// SSOT: Enabling Password AutoFill on a text input view — username + password.
public enum ProviderRememberLoginAutoFill {
    #if os(iOS)
    public static let usernameContentType = UITextContentType.username
    public static let passwordContentType = UITextContentType.password
    #else
    public static let usernameContentType = NSTextContentType.username
    public static let passwordContentType = NSTextContentType.password
    #endif
}
