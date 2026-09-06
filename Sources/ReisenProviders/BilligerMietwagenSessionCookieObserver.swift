import Foundation
import WebKit

/// Beobachtet Session-Cookies nach SPA-Login (`POST session.php` → Set-Cookie).
@MainActor
public final class BilligerMietwagenSessionCookieObserver: NSObject, WKHTTPCookieStoreObserver {
    private var lastPresence: Set<String> = []
    private let onSessionCookiesChanged: () -> Void
    private weak var cookieStore: WKHTTPCookieStore?

    public init(onSessionCookiesChanged: @escaping () -> Void) {
        self.onSessionCookiesChanged = onSessionCookiesChanged
    }

    public func attach(to cookieStore: WKHTTPCookieStore) {
        detach()
        self.cookieStore = cookieStore
        cookieStore.add(self)
        cookieStore.getAllCookies { [weak self] cookies in
            Task { @MainActor in
                _ = self?.applyCookies(cookies)
            }
        }
    }

    public func detach() {
        cookieStore?.remove(self)
        cookieStore = nil
    }

    public func cookiesDidChange(in cookieStore: WKHTTPCookieStore) {
        cookieStore.getAllCookies { [weak self] cookies in
            Task { @MainActor in
                guard let self, self.applyCookies(cookies) else { return }
                self.onSessionCookiesChanged()
            }
        }
    }

    /// Seed und Change-Pfad: aktualisiert die Präsenz; `true` nur bei Wechsel.
    @discardableResult
    public func applyCookies(_ cookies: [HTTPCookie]) -> Bool {
        let decision = BilligerMietwagenSessionProbe.shouldReprobeAfterCookieChange(
            previousPresence: lastPresence,
            currentCookies: cookies.map { ($0.name, !$0.value.isEmpty) }
        )
        lastPresence = decision.newPresence
        return decision.shouldReprobe
    }
}
