import Foundation
import WebKit

/// Markiert Login-Felder mit `autocomplete` und meldet dynamisch hinzugefügte Felder an Swift,
/// damit Credential-Fill auch bei mehrstufigen Logins (E-Mail → Kennwort) greift.
///
/// Hinweis: Das macOS-System-Passwort-Popover (Passwords-App) erscheint in eingebetteten
/// WKWebViews für Fremd-Domains ohne Browser-Entitlement nicht. Primärweg ist deshalb
/// „Konto speichern…“ + Ausfüllen (`LoginAutofill`). Ansatz 1 (Browser-Entitlement) später optional.
enum LoginFieldHints {
    static let messageHandlerName = "reisenLoginFields"

    @MainActor
    static func apply(in webView: WKWebView) {
        webView.evaluateJavaScript(script()) { _, _ in }
    }

    private static func script() -> String {
        """
        (function() {
          const handlerName = '\(messageHandlerName)';

          function notify() {
            try {
              if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers[handlerName]) {
                window.webkit.messageHandlers[handlerName].postMessage({ type: 'fieldsChanged' });
              }
            } catch (_) {}
          }

          // Debounce: Opodo/Booking SPAs re-rendern Login-DOM häufig; ohne Debounce
          // triggert jedes Mutation → Swift Fill → erneutes DOM-Rauschen und hängt z. B. bei „Anmelden…“.
          let notifyTimer = null;
          function scheduleNotify() {
            if (notifyTimer) clearTimeout(notifyTimer);
            notifyTimer = setTimeout(function() {
              notifyTimer = null;
              notify();
            }, 300);
          }

          function setAutocomplete(el, value) {
            if (!el || !el.setAttribute) return;
            const cur = (el.getAttribute('autocomplete') || '').toLowerCase();
            if (cur === value) return;
            // Sites setzen oft autocomplete="off" — für Password/Keychain-Hints überschreiben.
            if (!cur || cur === 'off' || cur === 'false') {
              el.setAttribute('autocomplete', value);
            }
          }

          function hay(el) {
            return [
              el.name, el.id, el.placeholder, el.getAttribute('aria-label'), el.getAttribute('autocomplete')
            ].map(v => (v || '').toLowerCase()).join(' ');
          }

          function candidatesUsername(el) {
            if (!el || el.tagName !== 'INPUT') return false;
            const type = (el.type || '').toLowerCase();
            if (type === 'password' || type === 'hidden' || type === 'submit' || type === 'button') return false;
            if (type === 'email') return true;
            return /(e-?mail|username|benutzer|user|login|account)/i.test(hay(el));
          }

          function candidatesPassword(el) {
            if (!el || el.tagName !== 'INPUT') return false;
            const type = (el.type || '').toLowerCase();
            if (type === 'password') return true;
            return /(current-password|password|passwort|kennwort|passwd)/i.test(hay(el));
          }

          function markFields(root) {
            const scope = root && root.querySelectorAll ? root : document;
            const inputs = scope.querySelectorAll ? scope.querySelectorAll('input') : [];
            let changed = false;
            for (const el of inputs) {
              if (candidatesUsername(el)) {
                const before = (el.getAttribute('autocomplete') || '').toLowerCase();
                setAutocomplete(el, 'username');
                if ((el.getAttribute('autocomplete') || '').toLowerCase() !== before) changed = true;
              }
              if (candidatesPassword(el)) {
                const before = (el.getAttribute('autocomplete') || '').toLowerCase();
                setAutocomplete(el, 'current-password');
                if ((el.getAttribute('autocomplete') || '').toLowerCase() !== before) changed = true;
              }
            }
            return changed;
          }

          if (window.__reisenLoginHintsInstalled) {
            if (markFields(document)) scheduleNotify();
            return true;
          }
          window.__reisenLoginHintsInstalled = true;

          markFields(document);
          scheduleNotify();

          const observer = new MutationObserver(function(mutations) {
            let sawInput = false;
            for (const m of mutations) {
              for (const node of m.addedNodes) {
                if (node.nodeType !== 1) continue;
                if (node.tagName === 'INPUT' || (node.querySelectorAll && node.querySelectorAll('input').length)) {
                  sawInput = true;
                }
              }
            }
            if (!sawInput) return;
            markFields(document);
            scheduleNotify();
          });
          observer.observe(document.documentElement || document.body, { childList: true, subtree: true });
          return true;
        })();
        """
    }
}
