import Foundation

/// JS: OTP-Felder (inkl. Check24 Shadow DOM) für Security Code AutoFill und Paste markieren.
public enum OneTimeCodeAutofillScript {
    public static func build(relaxSplitFieldMaxLength: Bool = false) -> String {
        """
        (function() {
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

            if ((type === 'tel' || type === 'number' || type === 'text' || inputMode === 'numeric')
                && Number.isFinite(maxLen) && maxLen === 1) {
              return true;
            }

            return false;
          }

          function setNativeValue(el, value) {
            if (!el) return;
            try {
              const tracker = el._valueTracker;
              if (tracker && typeof tracker.setValue === 'function') tracker.setValue('');
            } catch (_) {}
            const proto = window.HTMLInputElement && window.HTMLInputElement.prototype;
            const descriptor = proto && Object.getOwnPropertyDescriptor(proto, 'value');
            if (descriptor && descriptor.set) {
              descriptor.set.call(el, value);
            } else {
              el.value = value;
            }
            el.dispatchEvent(new Event('input', { bubbles: true }));
            el.dispatchEvent(new Event('change', { bubbles: true }));
          }

          function splitOTPGroup(el) {
            if (!el) return [el];
            let scope = el.parentElement;
            for (let depth = 0; depth < 6 && scope; depth += 1) {
              const inputs = collectInputsDeep(scope).filter(looksLikeOTP);
              const singles = inputs.filter(function(i) {
                const maxLen = parseInt(i.getAttribute('maxlength') || '', 10);
                return maxLen === 1 || i.getAttribute('data-reisen-otp-slot') === '1';
              });
              if (singles.length >= 4 && singles.length <= 8 && singles.indexOf(el) !== -1) {
                return singles;
              }
              if (inputs.length >= 4 && inputs.length <= 8 && inputs.indexOf(el) !== -1) {
                return inputs;
              }
              scope = scope.parentElement;
            }
            return [el];
          }

          function distributeDigits(startEl, digits) {
            const cleaned = String(digits || '').replace(/\\D/g, '');
            if (!cleaned || !startEl) return;
            const group = splitOTPGroup(startEl);
            const targets = group.length >= 4 ? group : [startEl];
            if (targets.length === 1) {
              setNativeValue(targets[0], cleaned);
              return;
            }
            for (let i = 0; i < targets.length; i += 1) {
              setNativeValue(targets[i], cleaned[i] || '');
            }
          }

          function digitsFromClipboard(event) {
            let text = '';
            try {
              text = (event.clipboardData && event.clipboardData.getData('text')) || '';
            } catch (_) {}
            return String(text).replace(/\\D/g, '');
          }

          function enablePaste(el) {
            if (!el || el.__reisenOTCPaste) return;
            el.__reisenOTCPaste = true;
            el.addEventListener('paste', function(event) {
              const digits = digitsFromClipboard(event);
              if (!digits) return;
              event.preventDefault();
              event.stopPropagation();
              distributeDigits(el, digits);
            }, true);
            el.addEventListener('input', function() {
              const v = String(el.value || '').replace(/\\D/g, '');
              if (v.length > 1) distributeDigits(el, v);
            });
          }

          function prepareSplitGroup(inputs) {
            const singles = inputs.filter(function(el) {
              if (!looksLikeOTP(el)) return false;
              const maxLen = parseInt(el.getAttribute('maxlength') || '', 10);
              return maxLen === 1;
            });
            if (singles.length < 4 || singles.length > 8) return;
            const first = singles[0];
            first.setAttribute('autocomplete', 'one-time-code');
            first.setAttribute('inputmode', 'numeric');
            first.setAttribute('pattern', '[0-9]*');
            first.setAttribute('data-reisen-otp-slot', '1');
            \(relaxSplitFieldMaxLength ? "first.setAttribute('maxlength', String(singles.length));" : "")
          }

          function markOTPFields(root) {
            const inputs = collectInputsDeep(root);
            prepareSplitGroup(inputs);
            let marked = 0;
            for (const el of inputs) {
              if (!looksLikeOTP(el)) continue;
              if (attr(el, 'autocomplete') !== 'one-time-code') {
                el.setAttribute('autocomplete', 'one-time-code');
                marked += 1;
              }
              el.setAttribute('inputmode', el.getAttribute('inputmode') || 'numeric');
              enablePaste(el);
            }
            return marked;
          }

          function installPasteOnRoot(root) {
            if (!root || root.__reisenOTCPasteRoot) return;
            root.__reisenOTCPasteRoot = true;
            root.addEventListener('paste', function(event) {
              const target = event.target;
              if (!target || target.tagName !== 'INPUT') return;
              if (!looksLikeOTP(target)) return;
              const digits = digitsFromClipboard(event);
              if (digits.length < 4) return;
              event.preventDefault();
              event.stopPropagation();
              distributeDigits(target, digits);
            }, true);
          }

          if (window.__reisenOTCInstalled) {
            markOTPFields(document);
            return true;
          }
          window.__reisenOTCInstalled = true;

          markOTPFields(document);
          installPasteOnRoot(document);
          walkOpenShadowRoots(document, function(r) { installPasteOnRoot(r); });

          const observer = new MutationObserver(function(mutations) {
            for (const m of mutations) {
              for (const node of m.addedNodes) {
                if (node.nodeType !== 1) continue;
                if (node.tagName === 'INPUT') {
                  markOTPFields(node.parentNode || document);
                } else if (node.querySelectorAll) {
                  markOTPFields(node);
                }
                if (node.shadowRoot) {
                  markOTPFields(node.shadowRoot);
                  installPasteOnRoot(node.shadowRoot);
                }
              }
            }
          });
          observer.observe(document.documentElement || document.body, { childList: true, subtree: true });
          return true;
        })();
        """
    }
}
