import Foundation
import WebKit

/// Beobachtet „Anmelden…“-Overlay für Debug.
/// Kein fetch/XHR-Monkeypatch: der hat Opodo GraphQL ggf. gestört (Hypothese V).
@MainActor
enum LoginSubmitDebugProbe {
    static let messageHandlerName = "reisenLoginDebug"

    static func addMessageHandler(to controller: WKUserContentController, handler: WKScriptMessageHandler & AnyObject) {
        controller.removeScriptMessageHandler(forName: messageHandlerName)
        controller.add(handler, name: messageHandlerName)
    }

    static func addUserScript(to controller: WKUserContentController) {
        controller.addUserScript(
            WKUserScript(source: script(), injectionTime: .atDocumentStart, forMainFrameOnly: false)
        )
    }

    static func script() -> String {
        """
        (function() {
          if (window.__reisenLoginSubmitProbe) return;
          window.__reisenLoginSubmitProbe = true;
          const handler = '\(messageHandlerName)';

          function post(payload) {
            try {
              if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers[handler]) {
                window.webkit.messageHandlers[handler].postMessage(payload);
              }
            } catch (_) {}
          }

          let lastBusy = false;
          function checkBusy() {
            const root = document.body || document.documentElement;
            if (!root) return;
            const text = (root.innerText || root.textContent || '').slice(0, 8000);
            const busy = /Anmelden\\s*\\.\\.\\./i.test(text)
              || /Signing\\s*in\\s*\\.\\.\\./i.test(text)
              || /Logging\\s*in\\s*\\.\\.\\./i.test(text);
            if (busy !== lastBusy) {
              lastBusy = busy;
              post({ type: 'busy', busy: busy, href: String(location.href).slice(0, 300) });
            }
          }

          const obs = new MutationObserver(function() { checkBusy(); });
          const start = function() {
            checkBusy();
            const root = document.documentElement || document.body;
            if (root) obs.observe(root, { childList: true, subtree: true, characterData: true });
          };
          if (document.readyState === 'loading') {
            document.addEventListener('DOMContentLoaded', start);
          } else {
            start();
          }
          setInterval(checkBusy, 1000);
        })();
        """
    }
}
