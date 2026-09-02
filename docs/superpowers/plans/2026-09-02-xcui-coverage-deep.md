# XCUI Coverage Deep Implementation Plan

**Goal:** Die macOS-XCUI-Suite prüft die relevanten Scope-C-Happy-Paths
inklusive isolierter Persistenz.

**Umfang:** Seed für offene Buchung und Gap, stabile
`UITestingIdentifiers`, Page-Object-Helfer, funktionale Smokes für Create,
Assign, Gap, Settings, Sync-Chrome und Paste-Import-Fixture.

**Nicht enthalten:** iOS-XCUI, CloudKit/Netzwerk, Provider-Login,
Portal-Cancel, Delete-Confirm, Multi-Select-Batch, Trip-Edit,
Sync-Erfolg sowie Paste-from-file/Drag-and-Drop.

## Page Object

- `openSeededTrip()`, `expandSidebarBookings()`, `selectSeededOpenBooking()`
- `openSettings()`, `openProviderSyncCheck24()`
- `createTripViaEmptyCTA(title:)`, `createTripViaMenu(title:)`
- `assignSeededOpenBookingToSeededTrip()`, `editSeededGapTitle(_:)`
- `launchPasteImportFixture()`
- Menü-Reach über DE-Titel: `newTripMenuTitleDE`, `assignBookingsMenuTitleDE`

## Smoke-Journeys (CI-Gate)

| # | Journey | End-Assert |
| --- | --- | --- |
| 1 | Empty → CTA → Create Trip | Sidebar zeigt Titel; Editor weg |
| 2 | Menü „Neue Reise…“ | Sheet → Save → Sidebar zeigt Titel |
| 3 | Trip Delete Dialog | Dialog → Escape; Trip-Row bleibt |
| 4 | Booking Inspector | `bookingEditorTitle` = Seed-Titel |
| 5 | Toolbar Add Booking | Create-Draft selected + `inspector` |
| 6 | Offene Buchung | Sidebar-Row → `inspector` |
| 7 | Assign | Confirm → Booking unter Seed-Trip |
| 8 | Gap | Titel-Override in Timeline sichtbar |
| 9 | Settings | Notification-Toggle kippt |
| 10 | Sync Chrome | `syncChrome` ohne WebView-Wait |
| 11 | Paste-Import Fixture | Accept → persistierte Booking-Zeile |
| 12 | Identifier-Unit | alle Konstanten + Gap-Formel |

## Verifikation

1. `bash ./Scripts/ci-test.sh`
2. Agents: `bash ./Scripts/macos-ui-test-remote.sh`
3. Bei Suite-Timeout (>45 min): CI-Job-Split laut Spec-v2, kein Timeout-Bump.

**TEST_HOST:** Der UI-Test-Target verwendet einen expliziten macOS-`TEST_HOST`,
damit der Xcode-Runner ein ausführbares Host-Ziel besitzt.
