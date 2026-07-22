import Foundation

/// JS-Quelle für Keychain-gestütztes Login-Ausfüllen in Provider-WKWebViews.
/// Mehrstufige Flows (zuerst E-Mail, später Kennwort) werden unterstützt.
public enum LoginAutofillScript {
    public static func build(username: String, password: String) -> String {
        let usernameLiteral = jsStringLiteral(username)
        let passwordLiteral = jsStringLiteral(password)

        return """
        (function() {
          const username = \(usernameLiteral);
          const password = \(passwordLiteral);

          function isVisible(el) {
            if (!el) return false;
            try {
              const rect = el.getBoundingClientRect ? el.getBoundingClientRect() : null;
              const hasRect = rect && (rect.width > 0 || rect.height > 0);
              if (hasRect) return true;
            } catch (_) {}
            try {
              return !!(el.offsetWidth || el.offsetHeight || (el.getClientRects && el.getClientRects().length));
            } catch (_) {}
            try {
              const cs = window.getComputedStyle ? window.getComputedStyle(el) : null;
              if (!cs) return false;
              if (cs.display === 'none') return false;
              if (cs.visibility === 'hidden') return false;
              if (cs.opacity === '0') return false;
              return true;
            } catch (_) {
              return false;
            }
          }

          // Check24: Login-Felder liegen im open Shadow DOM von <unified-login>.
          // querySelectorAll auf document findet sie nicht; closest() kreuzt Shadow-Grenzen nicht.
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
            return collectElementsDeep(root, 'input');
          }

          function collectElementsDeep(root, selector) {
            const out = [];
            walkOpenShadowRoots(root, (r) => {
              try {
                if (!r || !r.querySelectorAll) return;
                out.push(...Array.from(r.querySelectorAll(selector)));
              } catch (_) {}
            });
            return out;
          }

          function isInLoginUI(el) {
            if (!el) return false;
            try {
              if (el.closest && el.closest('.fullpage-login-box, unified-login')) return true;
            } catch (_) {}
            // Host-Kette: Element im Shadow Root → host = <unified-login>
            try {
              let root = el.getRootNode ? el.getRootNode() : null;
              while (root && root.host) {
                const host = root.host;
                const tag = (host.tagName || '').toLowerCase();
                if (tag === 'unified-login') return true;
                if (host.closest && host.closest('.fullpage-login-box, unified-login')) return true;
                root = host.getRootNode ? host.getRootNode() : null;
              }
            } catch (_) {}
            return false;
          }

          function inputDebug(el) {
            const visible = isVisible(el);
            let rect = null;
            try {
              rect = el && el.getBoundingClientRect ? el.getBoundingClientRect() : null;
            } catch (_) {
              rect = null;
            }
            let cs = null;
            try {
              cs = window.getComputedStyle ? window.getComputedStyle(el) : null;
            } catch (_) {
              cs = null;
            }
            const style = cs
              ? {
                  display: cs.display,
                  visibility: cs.visibility,
                  opacity: cs.opacity,
                }
              : { display: null, visibility: null, opacity: null };

            return {
              type: el && el.type ? el.type : null,
              tagName: el && el.tagName ? el.tagName : null,
              name: el && el.name ? el.name : null,
              id: el && el.id ? el.id : null,
              placeholder: el && el.placeholder ? el.placeholder : null,
              ariaLabel: el && el.getAttribute ? el.getAttribute('aria-label') : null,
              autocomplete: el && el.getAttribute ? el.getAttribute('autocomplete') : null,
              dataTestId: el && el.getAttribute ? el.getAttribute('data-testid') : null,
              dataQa: el && el.getAttribute ? el.getAttribute('data-qa') : null,
              dataCy: el && el.getAttribute ? el.getAttribute('data-cy') : null,
              valueLen: el && typeof el.value === 'string' ? el.value.length : 0,
              hay: (dataHay(el) || ''),
              inLoginUI: isInLoginUI(el),
              rect: rect
                ? { x: rect.x, y: rect.y, width: rect.width, height: rect.height }
                : { x: null, y: null, width: null, height: null },
              style,
              visible,
            };
          }

          function loginRoots() {
            const roots = [];
            try {
              for (const host of document.querySelectorAll('unified-login')) {
                if (host.shadowRoot) roots.push(host.shadowRoot);
                else roots.push(host);
              }
            } catch (_) {}
            try {
              const boxes = Array.from(document.querySelectorAll('.fullpage-login-box'));
              for (const box of boxes) {
                if (!roots.includes(box)) roots.push(box);
              }
            } catch (_) {}
            const dialogs = Array.from(document.querySelectorAll('[role="dialog"], [aria-modal="true"]')).filter(isVisible);
            for (const d of dialogs) {
              if (!roots.includes(d)) roots.push(d);
            }
            if (roots.length) return roots;
            return [document];
          }

          function labelText(el) {
            try {
              const label = el && el.closest ? el.closest('label') : null;
              if (!label || !label.innerText) return '';
              return label.innerText;
            } catch (_) {
              return '';
            }
          }

          function dataHay(el) {
            if (!el) return '';
            try {
              const attrs = [
                el.name,
                el.id,
                el.placeholder,
                el.className,
                el.getAttribute('aria-label'),
                el.getAttribute('autocomplete'),
                el.getAttribute('data-testid'),
                el.getAttribute('data-tid'),
                el.getAttribute('data-qa'),
                el.getAttribute('data-cy'),
              ];
              return attrs.join(' ') + ' ' + labelText(el);
            } catch (_) {
              return '';
            }
          }

          function looksLikeUsername(el) {
            if (!el || el.tagName !== 'INPUT') return false;
            const type = (el.type || '').toLowerCase();
            if (type === 'password' || type === 'hidden' || type === 'submit' || type === 'button' || type === 'checkbox') return false;
            if (type === 'email') return true;
            const hay = (dataHay(el) || '').toLowerCase();
            return /(e-?mail|username|benutzer|user|login|account|cl_login)/i.test(hay);
          }

          function looksLikePassword(el) {
            if (!el || el.tagName !== 'INPUT') return false;
            const type = (el.type || '').toLowerCase();
            if (type === 'password') return true;
            const hay = (dataHay(el) || '').toLowerCase();
            // Check24: #cl_pw_login / c24-uli-input-pw / autocomplete=current-password
            return /(current-password|password|passwort|kennwort|passwd|pwd|pass|cl_pw_login|uli-input-pw)/i.test(hay);
          }

          function looksLikeRemember(el) {
            if (!el || el.tagName !== 'INPUT') return false;
            if ((el.type || '').toLowerCase() !== 'checkbox') return false;
            const hay = (dataHay(el) || '').toLowerCase();
            // Check24: name=c24-uli-enable-longsession („Angemeldet bleiben“)
            return /(angemeldet.*bleiben|angemeldet bleiben|remember|merken|stay.?logged.?in|auto.?login|longsession|enable-longsession)/i.test(hay);
          }

          function canFill(el) {
            if (!el) return false;
            return isVisible(el) || isInLoginUI(el);
          }

          function collect(root, pred) {
            const out = [];
            for (const el of collectInputsDeep(root)) {
              if (pred(el) && canFill(el)) out.push(el);
            }
            return out;
          }

          function fill(el, value) {
            if (!el) return false;
            if (!canFill(el)) return false;

            const tracker = el._valueTracker;
            if (tracker && typeof tracker.setValue === 'function') {
              tracker.setValue('');
            }

            const proto = window.HTMLInputElement && window.HTMLInputElement.prototype;
            const descriptor = proto && Object.getOwnPropertyDescriptor(proto, 'value');
            if (descriptor && descriptor.set) {
              descriptor.set.call(el, value);
            } else {
              el.value = value;
            }
            el.dispatchEvent(new Event('input', { bubbles: true }));
            el.dispatchEvent(new Event('change', { bubbles: true }));
            return true;
          }

          function fillCheckbox(el) {
            if (!el) return false;
            if (el.type !== 'checkbox') return false;
            if (!canFill(el)) return false;
            el.checked = true;
            el.dispatchEvent(new Event('input', { bubbles: true }));
            el.dispatchEvent(new Event('change', { bubbles: true }));
            return true;
          }

          function looksLikeSubmit(el) {
            if (!el) return false;
            try {
              if (el.disabled) return false;
            } catch (_) {}
            const tag = (el.tagName || '').toLowerCase();
            const type = (el.type || '').toLowerCase();
            const role = (el.getAttribute && el.getAttribute('role') || '').toLowerCase();
            const isButton =
              tag === 'button' ||
              (tag === 'input' && (type === 'submit' || type === 'button')) ||
              role === 'button';
            if (!isButton) return false;
            const hay = [
              el.id,
              el.name,
              el.className,
              el.getAttribute && el.getAttribute('data-tid'),
              el.getAttribute && el.getAttribute('aria-label'),
              el.innerText || el.textContent || el.value || '',
            ].join(' ').toLowerCase();
            if (/(c24-uli-pw-btn|c24-uli-login-btn|submit-button|anmelden|einloggen|log.?in|sign.?in)/i.test(hay)) {
              return true;
            }
            // Generischer Submit im Login-UI (z.B. andere Provider).
            return type === 'submit' && isInLoginUI(el);
          }

          function clickSubmit(preferPasswordStep) {
            const selector = 'button, input[type="submit"], input[type="button"], [role="button"], [data-tid="submit-button"]';
            const candidates = [];
            for (const root of loginRoots()) {
              candidates.push(...collectElementsDeep(root, selector));
            }
            if (!candidates.length) {
              candidates.push(...collectElementsDeep(document, selector));
            }
            const scored = [];
            const seen = new Set();
            for (const el of candidates) {
              if (!el || seen.has(el)) continue;
              seen.add(el);
              if (!looksLikeSubmit(el) || !canFill(el)) continue;
              const id = (el.id || '').toLowerCase();
              let score = 0;
              if (preferPasswordStep && id === 'c24-uli-pw-btn') score += 100;
              if (!preferPasswordStep && id === 'c24-uli-login-btn') score += 100;
              if (id === 'c24-uli-pw-btn') score += 50;
              if (id === 'c24-uli-login-btn') score += 40;
              if ((el.getAttribute('data-tid') || '') === 'submit-button') score += 20;
              if (isVisible(el)) score += 10;
              scored.push({ el: el, score: score });
            }
            scored.sort((a, b) => b.score - a.score);
            if (!scored.length) return { clicked: false, submitId: null };
            const el = scored[0].el;
            try {
              el.click();
              return { clicked: true, submitId: el.id || el.getAttribute('data-tid') || null };
            } catch (_) {
              try {
                el.dispatchEvent(new MouseEvent('click', { bubbles: true, cancelable: true, view: window }));
                return { clicked: true, submitId: el.id || el.getAttribute('data-tid') || null };
              } catch (_) {
                return { clicked: false, submitId: null };
              }
            }
          }

          function allInputsDeep() {
            const main = collectInputsDeep(document);
            const iframes = Array.from(document.querySelectorAll('iframe'));
            const fromFrames = [];
            for (const iframe of iframes) {
              try {
                const doc = iframe && iframe.contentDocument ? iframe.contentDocument : null;
                if (!doc) continue;
                fromFrames.push(...collectInputsDeep(doc));
              } catch (_) {}
            }
            let shadowRoots = 0;
            walkOpenShadowRoots(document, (r) => {
              if (r && r !== document && r.host) shadowRoots += 1;
            });
            const seen = new Set();
            const out = [];
            for (const el of [...main, ...fromFrames]) {
              if (!el || seen.has(el)) continue;
              seen.add(el);
              out.push(el);
            }
            return { all: out, iframes: iframes.length, frameInputs: fromFrames.length, shadowRoots: shadowRoots };
          }

          let userFilled = 0;
          let passFilled = 0;
          let rememberFilled = 0;

          const agg = allInputsDeep();
          const allInputs = agg.all;
          const allVisibleInputs = allInputs.filter(isVisible);
          // Prefer login-UI inputs in debug (cookie checkboxes are noise).
          const loginInputs = allInputs.filter(isInLoginUI);
          const inputsDebug = (loginInputs.length ? loginInputs : allInputs).map(inputDebug).slice(0, 20);

          const usernameCandidatesAll = allInputs.filter(el => looksLikeUsername(el)).length;
          const usernameCandidatesVisible = allInputs.filter(el => looksLikeUsername(el) && canFill(el)).length;
          const passwordCandidatesAll = allInputs.filter(el => looksLikePassword(el)).length;
          const passwordCandidatesVisible = allInputs.filter(el => looksLikePassword(el) && canFill(el)).length;
          const rememberCandidatesAll = allInputs.filter(el => looksLikeRemember(el)).length;
          const rememberCandidatesVisible = allInputs.filter(el => looksLikeRemember(el) && canFill(el)).length;

          const roots = loginRoots();
          for (const root of roots) {
            for (const el of collect(root, looksLikeUsername)) {
              if (fill(el, username)) userFilled += 1;
            }
            for (const el of collect(root, looksLikePassword)) {
              if (fill(el, password)) passFilled += 1;
            }
            for (const el of collect(root, looksLikeRemember)) {
              if (fillCheckbox(el)) rememberFilled += 1;
            }
          }

          // Nach erfolgreichem Ausfüllen den sichtbaren „Anmelden“-Button klicken
          // (Check24: #c24-uli-pw-btn / #c24-uli-login-btn im Shadow DOM).
          let submitClicked = false;
          let submitId = null;
          if (userFilled > 0 || passFilled > 0) {
            const submitResult = clickSubmit(passFilled > 0);
            submitClicked = !!submitResult.clicked;
            submitId = submitResult.submitId;
          }

          return {
            filled: userFilled > 0 || passFilled > 0 || rememberFilled > 0,
            userFilled: userFilled,
            passFilled: passFilled,
            rememberFilled: rememberFilled,
            submitClicked: submitClicked,
            submitId: submitId,
            roots: roots.length,
            inputCountAll: allInputs.length,
            inputCountVisible: allVisibleInputs.length,
            iframes: agg.iframes,
            inputCountIframesAll: agg.frameInputs,
            shadowRoots: agg.shadowRoots,
            usernameCandidatesAll: usernameCandidatesAll,
            usernameCandidatesVisible: usernameCandidatesVisible,
            passwordCandidatesAll: passwordCandidatesAll,
            passwordCandidatesVisible: passwordCandidatesVisible,
            rememberCandidatesAll: rememberCandidatesAll,
            rememberCandidatesVisible: rememberCandidatesVisible,
            inputsDebug
          };
        })();
        """
    }

    private static func jsStringLiteral(_ s: String) -> String {
        let encoded = try! JSONEncoder().encode(s)
        let json = String(data: encoded, encoding: .utf8)!
        return json
    }
}
