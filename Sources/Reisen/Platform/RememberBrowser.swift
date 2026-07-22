import Foundation
import WebKit

enum RememberBrowser {
    /// Enables a provider's "remember/trusted device" option, without submitting the form.
    /// Returns whether any matching checkbox/radio was modified.
    static func scriptToRememberTrustedDevice() -> String {
        """
        (function() {
          const keywords = [
            // Generic / English.
            'remember',
            'trusted',
            'trust',
            'trusted device',
            'stay signed in',
            'keep me signed in',

            // German variants seen across providers / UIs.
            'merken',
            'angemeldet bleiben',
            'eingeloggt bleiben',
            'diesen browser merken',
            'diesen computer merken',
            'browser merken',
            'dieses gerät',
            'dieses gerät merken',
            'trusted device',
          ];

          function labelMatches(text) {
            const t = (text || '').toLowerCase();
            return keywords.some(k => t.includes(k));
          }

          function setChecked(el) {
            if (!el) return false;
            if (typeof el.checked === 'boolean') {
              if (!el.checked) {
                el.checked = true;
                el.dispatchEvent(new Event('input', { bubbles: true }));
                el.dispatchEvent(new Event('change', { bubbles: true }));
              }
              return true;
            }
            return false;
          }

          const directInputs = [
            ...document.querySelectorAll('input[type="checkbox"][name*="remember" i], input[type="checkbox"][id*="remember" i], input[type="checkbox"][name*="trust" i], input[type="checkbox"][id*="trust" i], input[type="checkbox"][name*="trusted" i], input[type="checkbox"][id*="trusted" i], input[type="checkbox"][name*="merken" i], input[type="checkbox"][id*="merken" i], input[type="checkbox"][name*="device" i], input[type="checkbox"][id*="device" i]')
          ];

          let changed = false;
          for (const i of directInputs) {
            changed = setChecked(i) || changed;
          }

          const labels = [...document.querySelectorAll('label')];
          for (const l of labels) {
            if (!labelMatches(l.innerText)) continue;

            // Prefer nested inputs.
            const nested = l.querySelector('input[type="checkbox"], input[type="radio"]');
            if (nested) {
              changed = setChecked(nested) || changed;
              continue;
            }

            // Fallback: label "for" attribute.
            const forId = l.getAttribute('for');
            if (forId) {
              const byId = document.getElementById(forId);
              changed = setChecked(byId) || changed;
            }
          }

          return changed;
        })();
        """
    }

    @MainActor
    static func apply(in webView: WKWebView) {
        webView.evaluateJavaScript(scriptToRememberTrustedDevice()) { _, _ in }
    }
}

