import Foundation

/// Live-belegte Check24-Storno-URL: Buchungsdetail + `?action=cancel`.
enum Check24CancellationURL {
    static let actionQueryName = "action"
    static let actionQueryValue = "cancel"
    private static let bookingPathMarker = "/kundenbereich/buchung/"

    /// Baut `{scheme}://{host}/kundenbereich/buchung/{id}?action=cancel` aus der Open-URL.
    static func fromBookingDetailURL(_ externalUrl: String) -> String? {
        let trimmed = externalUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let url = URL(string: trimmed),
              url.path.lowercased().contains(bookingPathMarker)
        else {
            return nil
        }
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }
        components.queryItems = [
            URLQueryItem(name: actionQueryName, value: actionQueryValue),
        ]
        components.fragment = nil
        return components.url?.absoluteString
    }
}
