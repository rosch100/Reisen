import Foundation
import Testing
import ReisenDomain
@testable import ReisenProviders

@Test func billigerMietwagenCancelAssist_shouldRunOnlyOnBookingDetail() {
    let detail = URL(
        string: "https://www.billiger-mietwagen.de/reservation/account/bookings/abc-123"
    )!
    let cancel = URL(string: "https://www.billiger-mietwagen.de/reservation/cancellation")!
    let other = URL(string: "https://www.example.com/reservation/account/bookings/abc-123")!

    #expect(BilligerMietwagenCancelAssist.isBookingDetailURL(detail))
    #expect(!BilligerMietwagenCancelAssist.isBookingDetailURL(cancel))
    #expect(!BilligerMietwagenCancelAssist.isBookingDetailURL(other))
    #expect(BilligerMietwagenCancelAssist.isCancellationPath(cancel))
    #expect(!BilligerMietwagenCancelAssist.isCancellationPath(detail))

    #expect(
        BilligerMietwagenCancelAssist.shouldRun(provider: .billigerMietwagen, loadedURL: detail)
    )
    #expect(
        !BilligerMietwagenCancelAssist.shouldRun(provider: .billigerMietwagen, loadedURL: cancel)
    )
    #expect(
        !BilligerMietwagenCancelAssist.shouldRun(provider: .getYourGuide, loadedURL: detail)
    )
}

@Test func billigerMietwagenCancelAssistScript_parsesStatuses() {
    #expect(
        BilligerMietwagenCancelAssistScript.parseClickStatus("clicked") == .clicked
    )
    #expect(
        BilligerMietwagenCancelAssistScript.parseClickStatus("button_missing") == .buttonMissing
    )
    #expect(
        BilligerMietwagenCancelAssistScript.parseClickStatus("already_scoped") == .alreadyScoped
    )
    #expect(
        BilligerMietwagenCancelAssistScript.parseClickStatus("generic_form") == .genericForm
    )
    #expect(BilligerMietwagenCancelAssistScript.parseClickStatus("nope") == nil)
    #expect(BilligerMietwagenCancelAssistScript.parsePollStatus("scoped") == .scoped)
    #expect(BilligerMietwagenCancelAssistScript.parsePollStatus("generic") == .generic)
    #expect(BilligerMietwagenCancelAssistScript.parsePollStatus("pending") == .pending)
    #expect(BilligerMietwagenCancelAssistScript.click.contains("Buchung"))
    #expect(BilligerMietwagenCancelAssistScript.poll.contains("/cancellation"))
    #expect(
        BilligerMietwagenCancelAssistScript.click.contains(
            BilligerMietwagenAuthConstants.portalHost
        )
    )
    #expect(
        !BilligerMietwagenCancelAssistScript.click.contains("indexOf('billiger-mietwagen.de')")
    )
}
