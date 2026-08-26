import Foundation

/// JS: Username/Kennwort aus Login-Formularen lesen (Submit) und an Swift melden.
public enum LoginFormCaptureScript {
    public static let messageHandlerName = "reisenLoginCapture"

    public static func build() -> String {
        """
        (function() {
          const handlerName = '\(messageHandlerName)';

          function postCredentials(username, password) {
            if (!username || !password) return;
            try {
              if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers[handlerName]) {
                window.webkit.messageHandlers[handlerName].postMessage({
                  type: 'credentials',
                  username: username,
                  password: password
                });
              }
            } catch (_) {}
          }

          function walkOpenShadowRoots(root, visit) {
            if (!root) return;
            visit(root);
            let nodes = [];
            try {
              nodes = root.querySelectorAll ? Array.from(root.querySelectorAll('*')) : [];
            } catch (_) {
              nodes = [];
            }
            for (const el of nodes) {
              try {
                if (el && el.shadowRoot) walkOpenShadowRoots(el.shadowRoot, visit);
              } catch (_) {}
            }
          }

          function collectInputsDeep(root) {
            const out = [];
            walkOpenShadowRoots(root || document, function(r) {
              try {
                if (r && r.querySelectorAll) out.push.apply(out, Array.from(r.querySelectorAll('input')));
              } catch (_) {}
            });
            return out;
          }

          function hay(el) {
            return [
              el.name, el.id, el.placeholder, el.getAttribute('aria-label'), el.getAttribute('autocomplete')
            ].map(function(v) { return (v || '').toLowerCase(); }).join(' ');
          }

          function looksLikeUsername(el) {
            if (!el || el.tagName !== 'INPUT') return false;
            const type = (el.type || '').toLowerCase();
            if (type === 'password' || type === 'hidden' || type === 'submit' || type === 'button') return false;
            if (type === 'email' || type === 'tel') return true;
            const inputmode = (el.getAttribute('inputmode') || '').toLowerCase();
            if (inputmode === 'tel' || inputmode === 'email') return true;
            return /(e-?mail|mobile|phone|telefon|handy|username|benutzer|user|login|account)/i.test(hay(el));
          }

          function looksLikePassword(el) {
            if (!el || el.tagName !== 'INPUT') return false;
            const type = (el.type || '').toLowerCase();
            if (type === 'password') return true;
            return /(current-password|password|passwort|kennwort|passwd)/i.test(hay(el));
          }

          function captureFromDocument() {
            const inputs = collectInputsDeep(document);
            let username = '';
            let password = '';
            for (const el of inputs) {
              if (!el || typeof el.value !== 'string') continue;
              const value = el.value.trim();
              if (!value) continue;
              if (!username && looksLikeUsername(el)) username = value;
              if (!password && looksLikePassword(el)) password = value;
            }
            postCredentials(username, password);
          }

          if (window.__reisenLoginCaptureInstalled) return true;
          window.__reisenLoginCaptureInstalled = true;

          document.addEventListener('submit', function() {
            captureFromDocument();
          }, true);

          document.addEventListener('click', function(event) {
            const target = event.target;
            if (!target) return;
            const tag = (target.tagName || '').toLowerCase();
            const type = (target.type || '').toLowerCase();
            const role = (target.getAttribute && target.getAttribute('role') || '').toLowerCase();
            const isSubmit =
              type === 'submit' ||
              (tag === 'button' && /(login|sign.?in|anmelden|continue|weiter)/i.test((target.innerText || target.textContent || '')));
            if (isSubmit || role === 'button' && type === 'submit') {
              captureFromDocument();
            }
          }, true);

          return true;
        })();
        """
    }
}
