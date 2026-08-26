import Foundation

extension BookingDetailsParser {
    func parseCurrency(from html: String) -> String? {
        // Aktuell nur € im Klartext; kann später auf weitere Währungen erweitert werden.
        return html.contains("€") ? "EUR" : nil
    }
}
