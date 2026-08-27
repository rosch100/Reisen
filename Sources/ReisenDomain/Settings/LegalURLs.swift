import Foundation

public enum LegalURLs {
    /// Datenschutz — In-App und ASC (GitHub Pages, locale-aware).
    public static var privacyPolicy: URL {
        GitHubRepository.pagesLegalURL(for: .privacy)
    }

    /// Support — In-App und ASC (GitHub Pages, locale-aware).
    public static var support: URL {
        GitHubRepository.pagesLegalURL(for: .support)
    }

    public static var privacyPolicyGerman: URL {
        GitHubRepository.pagesLegalURL(.privacyDE)
    }

    public static var privacyPolicyEnglish: URL {
        GitHubRepository.pagesLegalURL(.privacyEN)
    }

    public static var supportGerman: URL {
        GitHubRepository.pagesLegalURL(.supportDE)
    }

    public static var supportEnglish: URL {
        GitHubRepository.pagesLegalURL(.supportEN)
    }

    /// Raw-Fallback für ASC, solange GitHub Pages noch nicht deployed ist.
    public static var privacyPolicyRaw: URL {
        GitHubRepository.rawLegalURL(for: .privacy)
    }

    /// Raw-Fallback für Support.
    public static var supportRaw: URL {
        GitHubRepository.rawLegalURL(for: .support)
    }
}
