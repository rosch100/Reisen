import Foundation

/// JS for Expedia car cancel assist (DE HAR strings). Clicks entry + confirm; polls dialog gone.
public enum ExpediaCarCancelAssistScript {
    public enum StepStatus: String, Sendable {
        case clickedEntry = "clicked_entry"
        case clickedConfirm = "clicked_confirm"
        case alreadyConfirm = "already_confirm"
        case entryMissing = "entry_missing"
        case notCarCancel = "not_car_cancel"
        case wrongHost = "wrong_host"
        case dialogGone = "dialog_gone"
    }

    public enum PollStatus: String, Sendable {
        case pending
        case dialogOpen = "dialog_open"
        case dialogGone = "dialog_gone"
    }

    private static var portalHostCheckJS: String {
        let portal = ExpediaCarCancelAssist.portalHost
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
          var path = (location.pathname || '').toLowerCase();
          if (path.indexOf('/manage-booking') < 0) return 'entry_missing';
          var html = (document.documentElement && document.documentElement.innerHTML) || '';
          var bodyText = (document.body && document.body.innerText) || '';
          var isCar = /TripsCancelCarAction/i.test(html)
            || /cancelCar/i.test(html)
            || /TIM\\.CAR\\.NAV\\.CancelReservation/i.test(html);
          if (!isCar) return 'not_car_cancel';
          if (hasConfirmButton()) {
            clickLabel(/^Ja,\\s*jetzt\\s*stornieren$/i);
            return 'clicked_confirm';
          }
          if (hasEntryButton()) {
            clickLabel(/^Buchung\\s+stornieren$/i);
            return 'clicked_entry';
          }
          if (/Möchtest\\s+du\\s+deine\\s+Buchung\\s+wirklich\\s+stornieren/i.test(bodyText)) {
            return 'already_confirm';
          }
          return 'entry_missing';
          function normalize(s) {
            return (s || '').replace(/\\s+/g, ' ').trim();
          }
          function nodes() {
            return Array.prototype.slice.call(
              document.querySelectorAll('button, a, [role="button"]')
            );
          }
          function hasEntryButton() {
            var list = nodes();
            for (var i = 0; i < list.length; i++) {
              if (/^Buchung\\s+stornieren$/i.test(normalize(list[i].innerText || list[i].textContent || ''))) {
                return true;
              }
            }
            return false;
          }
          function hasConfirmButton() {
            var list = nodes();
            for (var i = 0; i < list.length; i++) {
              if (/^Ja,\\s*jetzt\\s*stornieren$/i.test(normalize(list[i].innerText || list[i].textContent || ''))) {
                return true;
              }
            }
            return false;
          }
          function clickLabel(re) {
            var list = nodes();
            for (var i = 0; i < list.length; i++) {
              var label = normalize(list[i].innerText || list[i].textContent || '');
              if (re.test(label)) { list[i].click(); return; }
            }
          }
        })()
        """
    }

    public static var poll: String {
        """
        (function() {
          var text = (document.body && document.body.innerText) || '';
          var nodes = Array.prototype.slice.call(
            document.querySelectorAll('button, a, [role="button"]')
          );
          var confirm = false;
          var deny = false;
          for (var i = 0; i < nodes.length; i++) {
            var l = ((nodes[i].innerText || nodes[i].textContent || '') + '')
              .replace(/\\s+/g, ' ').trim();
            if (/^Ja,\\s*jetzt\\s*stornieren$/i.test(l)) confirm = true;
            if (/^Nein,\\s*nicht\\s*stornieren$/i.test(l)) deny = true;
          }
          var question = /Möchtest\\s+du\\s+deine\\s+Buchung\\s+wirklich\\s+stornieren/i.test(text);
          if (confirm || deny || question) return 'dialog_open';
          return 'dialog_gone';
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
