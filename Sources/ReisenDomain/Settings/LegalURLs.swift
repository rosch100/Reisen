import Foundation

public enum LegalURLs {
    /// Datenschutz — In-App und ASC (gerenderte HTML via GitHub Pages).
    public static let privacyPolicy = GitHubRepository.pagesLegalURL(.privacy)

    /// Support — In-App und ASC (GitHub Pages).
    public static let support = GitHubRepository.pagesLegalURL(.support)

    /// Raw-Fallback für ASC, solange GitHub Pages noch nicht deployed ist.
    public static let privacyPolicyRaw = GitHubRepository.rawLegalURL(.privacy)

    /// Raw-Fallback für Support.
    public static let supportRaw = GitHubRepository.rawLegalURL(.support)
}
