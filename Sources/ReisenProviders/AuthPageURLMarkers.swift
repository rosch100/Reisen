import Foundation

/// Marker-Listen für Auth-URL-Heuristik (SSOT).
public enum AuthPageURLMarkers {
    public static let login = [
        "login", "anmelden", "signin", "sign-in", "sign_in",
        "identity", "authenticate", "auth/",
    ]

    public static let oneTimeCode = [
        "otp", "mfa", "2fa", "two-factor", "twofactor", "tan",
        "sicherheitscode", "verification-code", "verify-code", "verifycode",
        "auth-code", "authcode", "einmalcode", "one-time-code", "onetimecode",
        "one_time_code",
    ]

    public static let account = [
        "airbnb", "account", "activitylist", "activities", "kundenbereich",
        "mytrips", "my-bookings", "my-trips", "travel-center", "bookings",
        "/trips", "/travel/secure",
    ]
}
