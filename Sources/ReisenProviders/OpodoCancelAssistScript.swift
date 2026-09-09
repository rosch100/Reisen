import Foundation
import ReisenDomain

/// JS for Opodo cancel assist. Never clicks the final confirm control.
public enum OpodoCancelAssistScript {
    public enum StepStatus: String, Sendable {
        case alreadyOpen = "already_open"
        case clickedEntry = "clicked_entry"
        case entryMissing = "entry_missing"
        case wrongHost = "wrong_host"
        case alreadyCancelled = "already_cancelled"
    }

    public enum PollStatus: String, Sendable {
        case pending
        case dialogOpen = "dialog_open"
        case alreadyCancelled = "already_cancelled"
    }

    /// Regex source from Domain SSOT (`PortalCancelCompletionDetector`).
    private static var alreadyCancelledJSCheck: String {
        let pattern = PortalCancelCompletionDetector.opodoAlreadyCancelledPattern
        return "if (/\(pattern)/i.test(text)) return 'already_cancelled';"
    }

    private static var portalHostCheckJS: String {
        let portal = OpodoCancelAssist.portalHost
        return """
        var portal = '\(portal)';
        if (!(host === portal || host.slice(-(portal.length + 1)) === '.' + portal)) return 'wrong_host';
        """
    }

    public static var step: String {
        """
        (function() {
          var host = (location.hostname || '').toLowerCase();
          \(portalHostCheckJS)
          var text = (document.body && document.body.innerText) || '';
          \(alreadyCancelledJSCheck)
          if (hasConfirmDialog()) return 'already_open';
          var nodes = Array.prototype.slice.call(
            document.querySelectorAll('button, a, [role="button"]')
          );
          for (var i = 0; i < nodes.length; i++) {
            var label = normalize(nodes[i].innerText || nodes[i].textContent || '');
            if (/^diese\\s+buchung\\s+stornieren$/i.test(label)) continue;
            if (/buchung\\s+abbrechen/i.test(label)) {
              nodes[i].click();
              return 'clicked_entry';
            }
          }
          for (var j = 0; j < nodes.length; j++) {
            var label2 = normalize(nodes[j].innerText || nodes[j].textContent || '');
            if (/^diese\\s+buchung\\s+stornieren$/i.test(label2)) continue;
            if (/^stornieren$/i.test(label2) || /^buchung\\s+stornieren$/i.test(label2)) {
              nodes[j].click();
              return 'clicked_entry';
            }
          }
          return 'entry_missing';
          function normalize(s) {
            return (s || '').replace(/\\s+/g, ' ').trim();
          }
          function hasConfirmDialog() {
            var keep = false;
            var cancel = false;
            var list = Array.prototype.slice.call(
              document.querySelectorAll('button, a, [role="button"]')
            );
            for (var k = 0; k < list.length; k++) {
              var l = normalize(list[k].innerText || list[k].textContent || '');
              if (/diese\\s+buchung\\s+beibehalten/i.test(l)) keep = true;
              if (/diese\\s+buchung\\s+stornieren/i.test(l)) cancel = true;
            }
            return keep && cancel;
          }
        })()
        """
    }

    public static var poll: String {
        """
        (function() {
          var text = (document.body && document.body.innerText) || '';
          \(alreadyCancelledJSCheck)
          var keep = false;
          var cancel = false;
          var list = Array.prototype.slice.call(
            document.querySelectorAll('button, a, [role="button"]')
          );
          for (var i = 0; i < list.length; i++) {
            var l = ((list[i].innerText || list[i].textContent || '') + '')
              .replace(/\\s+/g, ' ').trim();
            if (/diese\\s+buchung\\s+beibehalten/i.test(l)) keep = true;
            if (/diese\\s+buchung\\s+stornieren/i.test(l)) cancel = true;
          }
          if (keep && cancel) return 'dialog_open';
          return 'pending';
        })()
        """
    }

    public static func parseStepStatus(_ raw: Any?) -> StepStatus? {
        guard let value = raw as? String else { return nil }
        return StepStatus(rawValue: value)
    }

    public static func parsePollStatus(_ raw: Any?) -> PollStatus? {
        guard let value = raw as? String else { return nil }
        return PollStatus(rawValue: value)
    }
}
