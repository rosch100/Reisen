import Foundation

/// JS: Login-Felder mit `autocomplete` markieren (Passwords AutoFill / Keychain-Fill).
public enum LoginFieldHintsScript {
    public static let messageHandlerName = "reisenLoginFields"

    public static func build() -> String {
        """
        (function() {
          const handlerName = '\(messageHandlerName)';

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
            try {
              if (root.querySelectorAll) {
                for (const host of root.querySelectorAll('unified-login')) {
                  if (host.shadowRoot) walkOpenShadowRoots(host.shadowRoot, visit);
                }
              }
            } catch (_) {}
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

          function notify() {
            try {
              if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers[handlerName]) {
                window.webkit.messageHandlers[handlerName].postMessage({ type: 'fieldsChanged' });
              }
            } catch (_) {}
          }

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
            if (!cur || cur === 'off' || cur === 'false') {
              el.setAttribute('autocomplete', value);
            }
          }

          function hay(el) {
            return [
              el.name, el.id, el.placeholder, el.getAttribute('aria-label'), el.getAttribute('autocomplete')
            ].map(function(v) { return (v || '').toLowerCase(); }).join(' ');
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
            const inputs = collectInputsDeep(root);
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
                if (node.shadowRoot) sawInput = true;
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
