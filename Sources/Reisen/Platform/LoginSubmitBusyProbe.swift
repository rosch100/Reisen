import Foundation
import WebKit

/// Beobachtet „Anmelden…“-/Signing-in-Overlay (Login-Busy), um Autofill zu pausieren und Session neu zu bewerten.
/// Kein fetch/XHR-Monkeypatch: der hat Opodo GraphQL ggf. gestört.
@MainActor
enum LoginSubmitBusyProbe {
    static let messageHandlerName = "reisenLoginBusy"
    /// Legacy-Name vor Rename; beim Attach/Dismantle mit entfernen.
    private static let legacyMessageHandlerName = "reisenLoginDebug"

    /// SSOT: Busy-Erkennung für UserScript und `evaluateJavaScript`.
    static var isBusyEvaluateScript: String {
        "(function() {\n\(busyCheckBody)\n})();"
    }

    static func removeMessageHandler(from controller: WKUserContentController) {
        controller.removeScriptMessageHandler(forName: legacyMessageHandlerName)
        controller.removeScriptMessageHandler(forName: messageHandlerName)
    }

    static func addMessageHandler(to controller: WKUserContentController, handler: WKScriptMessageHandler & AnyObject) {
        removeMessageHandler(from: controller)
        controller.add(handler, name: messageHandlerName)
    }

    static func addUserScript(to controller: WKUserContentController) {
        controller.addUserScript(
            WKUserScript(source: script(), injectionTime: .atDocumentStart, forMainFrameOnly: false)
        )
    }

    private static let busyCheckBody = """
            const root = document.body || document.documentElement;
            if (!root) return false;
            const text = (root.innerText || root.textContent || '').slice(0, 8000);
            return /Anmelden\\s*\\.\\.\\./i.test(text)
              || /Signing\\s*in\\s*\\.\\.\\./i.test(text)
              || /Logging\\s*in\\s*\\.\\.\\./i.test(text);
    """

    static func script() -> String {
        """
        (function() {
          if (window.__reisenLoginBusyProbe) return;
          window.__reisenLoginBusyProbe = true;
          const handler = '\(messageHandlerName)';

          function post(payload) {
            try {
              if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers[handler]) {
                window.webkit.messageHandlers[handler].postMessage(payload);
              }
            } catch (_) {}
          }

          function isBusy() {
            \(busyCheckBody)
          }

          let lastBusy = false;
          function checkBusy() {
            const busy = isBusy();
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
