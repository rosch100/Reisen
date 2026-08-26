import Foundation

/// JS: sichtbare E-Mail/Mobile/Benutzername-Anmeldemethode wählen (nicht Social/IdP).
public enum LoginMethodClickScript {
    public static func build() -> String {
        """
        (function() {
          function isVisible(el) {
            if (!el) return false;
            try {
              const rect = el.getBoundingClientRect ? el.getBoundingClientRect() : null;
              if (rect && (rect.width > 0 || rect.height > 0)) return true;
            } catch (_) {}
            try {
              return !!(el.offsetWidth || el.offsetHeight || (el.getClientRects && el.getClientRects().length));
            } catch (_) {
              return false;
            }
          }

          function elementHay(el) {
            if (!el) return '';
            try {
              const parts = [
                el.id,
                el.className,
                el.getAttribute('aria-label'),
                el.getAttribute('data-testid'),
                el.getAttribute('data-qa'),
                el.getAttribute('data-cy'),
                el.getAttribute('href'),
                el.innerText || el.textContent || el.value || '',
              ];
              return parts.join(' ').toLowerCase();
            } catch (_) {
              return '';
            }
          }

          function isSocialOrIdP(el) {
            const hay = elementHay(el);
            return /(sign.?in.?with|continue.?with|login.?with|anmelden.?mit|apple|google|facebook|\\bfb\\b|oauth|passkey)/i.test(hay);
          }

          function looksLikeEmailMobileMethod(el) {
            if (!el || !isVisible(el)) return false;
            if (isSocialOrIdP(el)) return false;
            const tag = (el.tagName || '').toLowerCase();
            const role = (el.getAttribute('role') || '').toLowerCase();
            const isClickable =
              tag === 'button' ||
              tag === 'a' ||
              role === 'button' ||
              (tag === 'input' && (el.type || '').toLowerCase() === 'button');
            if (!isClickable) return false;
            const hay = elementHay(el);
            if (/(e-?mail\\s*(or|oder|\\/|&|\\+|und)\\s*(mobile|mobil|phone|telefon|handy)|email\\s*or\\s*mobile|mobile\\s*or\\s*email)/i.test(hay)) {
              return true;
            }
            if (/(continue|weiter|login|sign.?in|anmelden|use|mit|with).*(e-?mail|email)/i.test(hay)) {
              return true;
            }
            if (/(e-?mail|email|mobile|mobil|phone|telefon|handy|username|benutzer).*(login|sign.?in|anmelden|continue|weiter)/i.test(hay)) {
              return true;
            }
            if (/^(e-?mail|email|mobile|mobil|phone|telefon|handy|username|benutzer)$/i.test((el.innerText || el.textContent || '').trim())) {
              return true;
            }
            return false;
          }

          function collectClickables(root) {
            const selector = 'button, a, [role="button"], input[type="button"], input[type="submit"]';
            try {
              return Array.from(root.querySelectorAll(selector));
            } catch (_) {
              return [];
            }
          }

          const candidates = collectClickables(document);
          const scored = [];
          for (const el of candidates) {
            if (!looksLikeEmailMobileMethod(el)) continue;
            const hay = elementHay(el);
            let score = 0;
            if (/email\\s*or\\s*mobile|e-?mail\\s*oder\\s*mobil/i.test(hay)) score += 100;
            if (/continue|weiter/i.test(hay)) score += 40;
            if (el.tagName === 'BUTTON') score += 10;
            scored.push({ el: el, score: score });
          }
          scored.sort(function(a, b) { return b.score - a.score; });
          if (!scored.length) return { clicked: false, label: null };
          const target = scored[0].el;
          try {
            target.click();
            return {
              clicked: true,
              label: (target.innerText || target.textContent || target.getAttribute('aria-label') || '').trim().slice(0, 120)
            };
          } catch (_) {
            try {
              target.dispatchEvent(new MouseEvent('click', { bubbles: true, cancelable: true, view: window }));
              return {
                clicked: true,
                label: (target.innerText || target.textContent || '').trim().slice(0, 120)
              };
            } catch (_) {
              return { clicked: false, label: null };
            }
          }
        })();
        """
    }
}
