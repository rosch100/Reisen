import Foundation
import WebKit

/// Marks OTP inputs in provider web pages so macOS/iOS Security Code AutoFill can suggest SMS/Mail codes.
enum OneTimeCodeAutofill {
    static func script() -> String {
        """
        (function() {
          if (window.__reisenOTCInstalled) {
            markOTPFields(document);
            return true;
          }
          window.__reisenOTCInstalled = true;

          function attr(el, name) {
            return (el.getAttribute(name) || '').toLowerCase();
          }

          function isExcluded(el) {
            const type = (el.type || '').toLowerCase();
            if (type === 'password' || type === 'hidden' || type === 'submit' || type === 'button' || type === 'checkbox' || type === 'radio' || type === 'file') {
              return true;
            }
            const auto = attr(el, 'autocomplete');
            if (auto === 'username' || auto === 'current-password' || auto === 'new-password' || auto === 'email') {
              return true;
            }
            const hay = [attr(el, 'name'), attr(el, 'id'), attr(el, 'placeholder'), attr(el, 'aria-label')].join(' ');
            if (/(password|passwort|username|benutzer|e-?mail)/i.test(hay)) {
              return true;
            }
            return false;
          }

          function looksLikeOTP(el) {
            if (!el || el.tagName !== 'INPUT') return false;
            if (isExcluded(el)) return false;

            const auto = attr(el, 'autocomplete');
            if (auto === 'one-time-code') return true;

            const hay = [attr(el, 'name'), attr(el, 'id'), attr(el, 'placeholder'), attr(el, 'aria-label'), attr(el, 'autocomplete')].join(' ');
            if (/(one[-_ ]?time|otp|mfa|2fa|tan|sicherheitscode|verification.?code|auth.?code|einmalcode|sms.?code|email.?code)/i.test(hay)) {
              return true;
            }

            const inputMode = attr(el, 'inputmode');
            const type = (el.type || '').toLowerCase();
            const maxLen = parseInt(el.getAttribute('maxlength') || '', 10);
            const shortNumeric = (type === 'tel' || type === 'number' || inputMode === 'numeric' || inputMode === 'tel')
              && Number.isFinite(maxLen) && maxLen > 0 && maxLen <= 8;
            if (shortNumeric) return true;

            // Split OTP: several single-digit inputs in the same form/container.
            if ((type === 'tel' || type === 'number' || type === 'text' || inputMode === 'numeric')
                && Number.isFinite(maxLen) && maxLen === 1) {
              return true;
            }

            return false;
          }

          function markOTPFields(root) {
            const scope = root && root.querySelectorAll ? root : document;
            const inputs = scope.querySelectorAll ? scope.querySelectorAll('input') : [];
            let marked = 0;
            for (const el of inputs) {
              if (!looksLikeOTP(el)) continue;
              if (attr(el, 'autocomplete') !== 'one-time-code') {
                el.setAttribute('autocomplete', 'one-time-code');
                marked += 1;
              }
            }
            return marked;
          }

          markOTPFields(document);

          const observer = new MutationObserver(function(mutations) {
            for (const m of mutations) {
              for (const node of m.addedNodes) {
                if (node.nodeType !== 1) continue;
                if (node.tagName === 'INPUT') {
                  markOTPFields(node.parentNode || document);
                } else if (node.querySelectorAll) {
                  markOTPFields(node);
                }
              }
            }
          });
          observer.observe(document.documentElement || document.body, { childList: true, subtree: true });
          return true;
        })();
        """
    }

    @MainActor
    static func apply(in webView: WKWebView) {
        webView.evaluateJavaScript(script()) { _, _ in }
    }
}
