import Foundation

/// JS status strings for BM cancel assist (no booking IDs / PII).
public enum BilligerMietwagenCancelAssistScript {
    public enum ClickStatus: String, Sendable {
        case clicked
        case buttonMissing = "button_missing"
        case alreadyScoped = "already_scoped"
        case genericForm = "generic_form"
        case cancelUnknown = "cancel_unknown"
        case wrongHost = "wrong_host"
    }

    public enum PollStatus: String, Sendable {
        case pending
        case scoped
        case generic
    }

    private static var portalHostJS: String { BilligerMietwagenAuthConstants.portalHost }
    private static var cancellationPathJS: String { BilligerMietwagenAuthConstants.cancellationPath }

    private static var portalHostCheckJS: String {
        let portal = portalHostJS
        return """
        var portal = '\(portal)';
        if (!(host === portal || host.slice(-(portal.length + 1)) === '.' + portal)) return 'wrong_host';
        """
    }

    public static var click: String {
        """
        (function() {
          var host = (location.hostname || '').toLowerCase();
          \(portalHostCheckJS)
          var path = location.pathname || '';
          var text = (document.body && document.body.innerText) || '';
          if (path.indexOf('\(cancellationPathJS)') >= 0) {
            if (text.indexOf('Prüfe bitte') >= 0) return 'already_scoped';
            if (text.indexOf('Welche Buchung') >= 0) return 'generic_form';
            return 'cancel_unknown';
          }
          var nodes = Array.prototype.slice.call(
            document.querySelectorAll('button, a, [role="button"]')
          );
          var btn = null;
          for (var i = 0; i < nodes.length; i++) {
            var label = ((nodes[i].innerText || nodes[i].textContent || '') + '').replace(/\\s+/g, ' ').trim();
            if (/Buchung\\s+stornieren/i.test(label)) { btn = nodes[i]; break; }
          }
          if (!btn) return 'button_missing';
          btn.click();
          return 'clicked';
        })()
        """
    }

    public static var poll: String {
        """
        (function() {
          var path = location.pathname || '';
          var text = (document.body && document.body.innerText) || '';
          if (path.indexOf('\(cancellationPathJS)') < 0) return 'pending';
          if (text.indexOf('Prüfe bitte') >= 0) return 'scoped';
          if (text.indexOf('Welche Buchung') >= 0) return 'generic';
          return 'pending';
        })()
        """
    }

    public static func parseClickStatus(_ raw: Any?) -> ClickStatus? {
        guard let value = raw as? String else { return nil }
        return ClickStatus(rawValue: value)
    }

    public static func parsePollStatus(_ raw: Any?) -> PollStatus? {
        guard let value = raw as? String else { return nil }
        return PollStatus(rawValue: value)
    }
}
