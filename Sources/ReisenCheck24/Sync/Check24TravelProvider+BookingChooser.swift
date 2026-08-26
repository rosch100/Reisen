import Foundation
import WebKit

extension Check24TravelProvider {
    /// Check24 zeigt bei verknüpften Hotelbuchungen oft „Wählen Sie Ihre Buchung“ —
    /// ohne Klick fehlen Storno-/Detail-Daten. Passenden Eintrag automatisch wählen.
    func dismissBookingChooserIfNeeded(
        in webView: WKWebView,
        for parsedBooking: ParsedBooking
    ) async {
        var needles: [String] = []
        if let title = parsedBooking.title, !title.isEmpty { needles.append(title) }
        if let code = parsedBooking.confirmationCode, !code.isEmpty { needles.append(code) }
        if let url = parsedBooking.externalUrl, let bookingID = url.split(separator: "/").last {
            needles.append(String(bookingID))
        }
        await dismissBookingChooserIfNeeded(in: webView, needles: needles)
    }

    func dismissBookingChooserIfNeeded(
        in webView: WKWebView,
        needles: [String]
    ) async {
        let cleaned = needles
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let needlesJSON: String
        if let data = try? JSONSerialization.data(withJSONObject: cleaned),
           let text = String(data: data, encoding: .utf8) {
            needlesJSON = text
        } else {
            needlesJSON = "[]"
        }

        let script = """
        (function() {
          const needles = \(needlesJSON).map(s => String(s || '').toLowerCase()).filter(Boolean);
          const root = document.body;
          if (!root) return false;

          const hasChooser = /Wählen Sie Ihre Buchung/i.test(root.innerText || '');
          if (!hasChooser) return false;

          function visible(el) {
            if (!el) return false;
            const r = el.getBoundingClientRect();
            const style = window.getComputedStyle(el);
            return r.width > 8 && r.height > 8
              && style.visibility !== 'hidden'
              && style.display !== 'none'
              && style.opacity !== '0';
          }

          function score(el) {
            const text = (el.innerText || el.textContent || '').toLowerCase();
            let s = 0;
            for (const n of needles) {
              if (n && text.includes(n)) s += 10;
            }
            if (/aktiv/i.test(text)) s += 1;
            return s;
          }

          const candidates = Array.from(root.querySelectorAll('button, a, [role="button"], li, div'))
            .filter(visible)
            .filter(el => {
              const text = (el.innerText || '').trim();
              if (text.length < 8 || text.length > 800) return false;
              return /€|aktiv|zimmer|doppel|suite|buchung/i.test(text);
            });

          let best = null;
          let bestScore = 0;
          for (const el of candidates) {
            const s = score(el);
            if (s > bestScore) {
              bestScore = s;
              best = el;
            }
          }

          if (!best || bestScore < 1) {
            best = candidates.find(el => /€/.test(el.innerText || '')) || null;
          }
          if (!best) return false;

          best.click();
          return true;
        })();
        """

        for _ in 1...6 {
            let hasChooser = await webView.evaluateJavaScriptBoolAsync(
                "/Wählen Sie Ihre Buchung/i.test((document.body && document.body.innerText) || '')"
            )
            guard hasChooser else { return }

            _ = await webView.evaluateJavaScriptBoolAsync(script)
            try? await Task.sleep(nanoseconds: 450_000_000)

            let stillOpen = await webView.evaluateJavaScriptBoolAsync(
                "/Wählen Sie Ihre Buchung/i.test((document.body && document.body.innerText) || '')"
            )
            if !stillOpen { return }
        }
    }
}
