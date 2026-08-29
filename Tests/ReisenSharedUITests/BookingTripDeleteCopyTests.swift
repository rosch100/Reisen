import Foundation
import Testing
import ReisenDomain
import ReisenSharedUI

/// Sprachen aus `Localizable.xcstrings` (`sourceLanguage` plus Übersetzungen).
private let catalogLanguages = ["de", "en"]

@Suite(.serialized)
struct BookingTripDeleteCopyTests {
    private func withCatalogLanguage(_ language: String, _ body: () -> Void) {
        let previous = L10n.locale
        L10n.locale = Locale(identifier: language)
        defer { L10n.locale = previous }
        body()
    }

    @Test(arguments: catalogLanguages, [false, true])
    func bookingDeleteMessage_usesMatchingCatalogKey(_ language: String, showsSyncRestoreWarning: Bool) {
        withCatalogLanguage(language) {
            let text = BookingTripActions.bookingDeleteMessage(showsSyncRestoreWarning: showsSyncRestoreWarning)
            let expected = L10n.string(
                showsSyncRestoreWarning ? .bookingDeleteConfirmMessageSynced : .bookingDeleteConfirmMessage
            )
            #expect(text == expected)
            #expect(
                BookingTripActions.bookingDeleteMessage(showsSyncRestoreWarning: true)
                    != BookingTripActions.bookingDeleteMessage(showsSyncRestoreWarning: false)
            )
        }
    }

    @Test(arguments: catalogLanguages)
    func bookingDeleteTitle_includesName(_ language: String) {
        withCatalogLanguage(language) {
            let named = BookingTripActions.bookingDeleteTitle(named: "Italien")
            #expect(named == L10n.format(.bookingDeleteConfirmTitleNamed, "Italien"))
            #expect(named.contains("Italien"))
        }
    }

    @Test(arguments: catalogLanguages)
    func tripDeleteMessage_emptyVsWithBookings(_ language: String) {
        withCatalogLanguage(language) {
            let empty = BookingTripActions.tripDeleteMessage(bookingCount: 0)
            let one = BookingTripActions.tripDeleteMessage(bookingCount: 1)
            let several = BookingTripActions.tripDeleteMessage(bookingCount: 2)
            #expect(empty == L10n.string(.tripDeleteConfirmMessageEmpty))
            #expect(one == L10n.string(.tripDeleteConfirmMessageWithBookings))
            #expect(several == one)
            #expect(empty != one)
            #expect(one.contains(L10n.string(.tripDeleteKeepBookings)))
            #expect(one.contains(L10n.string(.tripDeleteWithBookings)))
        }
    }

    @Test(arguments: catalogLanguages)
    func tripDeleteTitle_namedAndFallback(_ language: String) {
        withCatalogLanguage(language) {
            let named = BookingTripActions.tripDeleteTitle(named: "Italien")
            #expect(named == L10n.format(.tripDeleteConfirmTitleNamed, "Italien"))
            #expect(named.contains("Italien"))
            #expect(BookingTripActions.tripDeleteTitle(named: "") == L10n.string(.actionDeleteTripConfirm))
            #expect(BookingTripActions.tripDeleteTitle(named: nil) == L10n.string(.actionDeleteTripConfirm))
        }
    }

    @Test(arguments: catalogLanguages)
    func tripDeleteDialogActionLabelsAreDistinct(_ language: String) {
        withCatalogLanguage(language) {
            let withBookings = L10n.string(.tripDeleteWithBookings)
            let keep = L10n.string(.tripDeleteKeepBookings)
            #expect(!withBookings.isEmpty)
            #expect(!keep.isEmpty)
            #expect(withBookings != keep)
        }
    }

    @Test(arguments: catalogLanguages)
    func persistFailureTitle_isDedicatedWithoutPlaceholder(_ language: String) {
        withCatalogLanguage(language) {
            let title = L10n.string(.errorPersistFailed)
            #expect(!title.isEmpty)
            #expect(!title.contains("%"))
            #expect(title != L10n.string(.tripAssignFailed))
        }
    }
}
