# Globale Buchungs-Tagesüberschneidungen (macOS + iOS)

**Datum:** 2026-09-01
**Status:** Entwurf für Implementierung (Review-Findings eingearbeitet)
**Plattformen:** macOS (`Reisen`) und iOS/iPadOS (`ReiseniOS`)

## Ziel

1. **SSOT:** Dieselbe Domain-Heuristik und dieselbe L10n-/A11y-Anzeige auf macOS und iOS.
2. **Reiseübergreifend:** Overlaps über **alle** persistierten Buchungen (zugeordnet + offen), nicht nur innerhalb einer Reise.
3. **Typ-Regel Occupancy:** nur Hotel half-open; alle anderen Typen inclusive End (inkl. Nachtflug/Mietwagen); Mehrfachzimmer-Ausnahme nur **innerhalb derselben Reise**.

Dies ist **nicht** Backlog-F24 (Provider-Duplikat-Hinweis). F24 bleibt geplant/eigene Spec.

## Ist-Zustand

| Teil | Verhalten |
|------|-----------|
| Domain | `BookingDayOverlap.countsByID([BookingDaySpan])` — alle Typen half-open; Same-Place+Same-Dates **immer** kein Overlap (ohne Trip-Bezug) |
| Kalender | `Calendar.current` — driftet zu `HotelStayDate` (GMT-Datumsanker) |
| Same-Day Flug | `startDay == endDay` → leere half-open-Spanne → nie Overlap |
| macOS | `TripDetailView` hat bereits `@Query` aller Bookings, Counts aber nur aus Trip-Buchungen; Farbe-only Caption |
| iOS | Keine Overlap-Anzeige |
| Offen (macOS) | `BookingDetailContent` oft ohne Overlap-Parameter |
| Sidebar (macOS) | Buchungszeilen ohne Overlap |
| Status | `BookingStatus`: `confirmed` / `cancelled` / `unknown` — kein `refunded` |

## Begriffe (SSOT)

| Begriff | Bedeutung |
|---------|-----------|
| **Overlap-Kalender** | Immer `HotelStayDate.calendar` (Gregorian, GMT) — SSOT zu Hotel-Datumsankern; kein `Calendar.current` in Overlap-Pfaden |
| **Belegungsintervall** | Half-open `[occupiedStart, occupiedEndExclusive)` auf Kalendertagen dieses Kalenders |
| **Stay-artig (half-open End)** | Nur `hotel` (`usesStayLikeOverlapEnd == true`): `[startDay, endDay)` — Checkout-Tag **nicht** belegt |
| **Punkt-/Event-/Transport-artig (inclusive End)** | Alle übrigen Typen inkl. `carRental`: `[startDay, endDay + 1 Tag)` — End-Kalendertag **mit** belegt |
| **Adjacent (Stay)** | Hotel-Checkout-Tag == Hotel-Checkin-Tag → Occupied berühren sich nur am Rand → **kein** Overlap |
| **Same-Place+Same-Dates** | Nicht-leerer gleicher `placeKey` und gleiche Roh-Start-/End-Tage |
| **Multi-Room-Suppress** | Same-Place+Same-Dates **und** beide `tripID` non-nil und **gleich** → kein Overlap |
| **Offen** | `tripID == nil` |
| **Overlap-Pool** | Alle Buchungen mit `isInOverlapPool` ≡ `isEligible` **und nicht** `BookingListInclusion.isElapsed` (Subjekt und Partner). |
| **Overlap-Partner** | Andere Pool-Buchungen mit Intervall-Schnitt; Map `[UUID: [UUID]]` nur bei ≥1 Partner |
| **Caption (L10n)** | Partner-Titel nennen (`Überschneidung mit …`); kein `(+N)`-Count-Badge; `.help` listet alle Titel |

## Entscheidungen

| Thema | Wahl |
|-------|------|
| Pool | Persistierte außer `cancelled` **und** außer abgelaufenen (`isElapsed`) |
| Scope | Reiseübergreifend inkl. offen |
| Same-Place | Suppress nur intra-Trip |
| Occupancy | **Typ-Regel** über `BookingType.usesStayLikeOverlapEnd` (kein generischer Same-Day-Clamp allein) |
| Kalender | Nur `HotelStayDate.calendar` (Occupancy); Elapsed über `Calendar.current` (SSOT Liste) |
| Personenfilter | Out of Scope |
| Architektur | Domain erweitert; Shared Compute; UI Lookup + Label |
| Sidebar macOS | **In Scope v1** |
| HIG/A11y | Symbol + Partner-Text + `accessibilityLabel`; macOS `.help` mit voller Partnerliste |
| F24 / Deep-Link / Auto-Dedup | Out of Scope / geplant |

## Architektur

### Domain

`BookingDaySpan` erweitern um:

- `tripID: UUID?` (`nil` = offen)
- `bookingType: BookingType` (Occupancy-SSOT)

**`BookingType.usesStayLikeOverlapEnd` (neue SSOT-Property, exhaustive switch):**

| `BookingType` | Stay-artig (`true`) | Begründung |
|---------------|---------------------|------------|
| `hotel` | ja | Übernachtung; Checkout-Tag exclusive (Branchen-Standard) |
| `carRental` | nein | Rückgabetag oft noch belegt bis Uhrzeit; analog Reise/Event |
| `flight` | nein | Reisetag(e) inkl. Ankunft (Nachtflug = beide Kalendertage) |
| `ferry` | nein | analog Transport |
| `train` | nein | analog Transport |
| `activity` | nein | Event-Tag(e) inklusive |
| `other` | nein | konservativ inklusive |

Nur **Hotel** ist half-open. Alle übrigen Typen: inclusive End.

**Occupancy (SSOT):**

```
cal = HotelStayDate.calendar
startDay = cal.startOfDay(for: startAt)
endDay   = cal.startOfDay(for: endAt)

// Invariante: endDay >= startDay (Entity/Sync). Wenn endDay < startDay:
// kein Raten — Occupancy leer / kein Overlap mit anderen (kein Dummy-Clamp).
guard endDay >= startDay else { occupied = empty }

if bookingType.usesStayLikeOverlapEnd:
    occupied = [startDay, endDay)                    // half-open
else:
    occupied = [startDay, endDay + 1 calendar day) // inclusive End
```

Beispiele:

| Typ | start→end (Kalendertage) | Belegt |
|-----|--------------------------|--------|
| Hotel | 1.–3. | 1., 2. (nicht 3.) |
| Hotel | 1.–2. (eine Nacht) | 1. |
| Flug | 1.–1. | 1. |
| Flug | 1.–2. (Nachtflug) | 1. und 2. |
| Mietwagen | 1.–3. | 1., 2. und 3. |
| Activity | 5.–5. | 5. |

`dayRangesOverlap` vergleicht **occupied**-Intervalle.

**Matching (Reihenfolge) in Counting:**

1. Andere `id`
2. `shouldSuppressAsMultiRoom(a, b)` → skip
3. Occupied-Intervalle schneiden → Count +1

`shouldSuppressAsMultiRoom` = Same-Place+Same-Dates **und** `a.tripID == b.tripID`, beide non-nil.
Altes „Same-Place zählt nie“ entfällt.

**Eligibility-SSOT:** `isEligible(status:)` ≡ `!= .cancelled`.
**Pool-SSOT:** `isInOverlapPool` ≡ eligible **und** nicht `isElapsed`. Overlap-Pool ≠ `BookingListInclusion.appearsInList`.

**Cancelled / elapsed als Subjekt:** Nicht im Pool → kein Label.

**Factories:**

- `Booking.daySpan` → `tripID`, `bookingType`
- `SDBooking.daySpan` → `trip?.id`, `bookingType`

**Shared Compute:**

- Domain: `partnerIDsByID(_ spans:)`, `countsByID` (abgeleitet), `isEligible` / `isInOverlapPool`
- Data: `BookingDayOverlap.partnerIDsByID(sdBookings:)` — Pool-Filter → `daySpan` → Domain

Views nur Data-Helfer + Titel-Lookup (`presentationTitle`). Default-Occupancy-Calendar: `HotelStayDate.calendar`.

### UI (dünn, Parität)

1. `@Query` aller `SDBooking` (Parent)
2. `partners = BookingDayOverlap.partnerIDsByID(sdBookings:)`
3. Titel via `presentationTitle`; Anzeige wenn Partner-Titel nicht leer

**Label-SSOT (SharedUI):** SF Symbol `exclamationmark.triangle` + `L10n.overlapLabel(partnerTitles:)` + Farbe ergänzend + `.accessibilityLabel` = L10n-String; macOS `.help` = volle Partnerliste.

**`OpenBookingRow`:**

```swift
public init(
    booking: SDBooking,
    fillCaption: String? = nil,
    partnerTitles: [String]
)
```

| Fläche | macOS | iOS |
|--------|-------|-----|
| Trip-Timeline / Zeile | Pool global | `OpenBookingRow(partnerTitles:)` |
| Buchungsdetail | `BookingDetailContent` | `BookingDetailIOS` |
| Offene Buchung Detail | Overlap setzen | `BookingDetailIOS` |
| Offen-Liste | `OpenBookingRow` | `OpenBookingRow` |
| Sidebar Buchungszeile | Badge/Caption | Listenzeilen |

### Fehler / fehlende Daten

- Leerer `placeKey` → kein Multi-Room-Suppress.
- `tripID == nil` → kein Suppress.
- `endDay < startDay` → leere Occupancy, kein Dummy-Tages-Clamp.
- Keine Dummy-Trip-IDs, keine stillen Fallbacks.

## Out of Scope

- Auto-Dedup / Löschen
- F24 Provider-Duplikat-Heuristik
- Passagier-/Gästegleichheit
- Navigation „zeige Konfliktbuchung“
- Live Activity / Widget
- Deep-Link / Navigation zur Konfliktbuchung (Caption nennt Partner; Sprung bleibt OOS)

## Tests (Domain)

1. Überlappende Hotel-Nächte, verschiedene `tripID` → Counts ≥ 1
2. Offen ↔ Reise, überlappende Nächte → Count
3. Same-Place+Same-Dates, gleiche `tripID` → kein Count
4. Same-Place+Same-Dates, verschiedene `tripID` / offen → Count
5. `cancelled` Partner → kein Count
6. Adjacent Hotel Checkout=Checkin → kein Overlap
7. Same-Day Flug vs. Same-Day Flug → Count ≥ 1
8. Same-Day Flug vs. Hotel, das denselben Tag als Nacht belegt → Count
9. Hotel 1.–3. vs. Flug nur am 3. (Checkout-Tag) → **kein** Overlap
10. Activity Same-Day vs. Activity Same-Day → Count
11. `unknown` eligible
12. Default-Calendar = `HotelStayDate.calendar`
13. `usesStayLikeOverlapEnd`: nur `.hotel == true`; alle anderen Cases `false` (exhaustive)
14. Mietwagen 1.–3. vs. Hotel-Nacht nur 2.–3. → Overlap
15. `endDay < startDay` → leere Occupancy, kein Overlap (kein Dummy-Clamp)

## Offene Lücken (open_gaps)

Bewusst nicht v1:

- XCUI / Live-Screenshot Overlap-Caption
- Deep-Link zur Konfliktbuchung
- Personenfilter
- F24 Provider-Duplikat

**Entry-Evidence v1:** SharedUI-Unit Caption-Text/A11y/Visibility; Parent-Lookup `countsByID(sdBookings:)`. Kein XCUI-Gate.

## Schnittstellen (Inventar)

| id | kind | supply | evidence |
|----|------|--------|----------|
| overlap-contract | contract | Occupancy + Suppress + `isEligible` + `countsByID` | `BookingDayOverlapTests` |
| daySpan-neighbor | neighbor | `Booking`/`SDBooking.daySpan` + `HotelStayDate.calendar` | Factory-/Data-Tests |
| overlap-ui-entry | entry | SharedUI Caption in Trip/Offen/Sidebar/Detail (macOS+iOS) | `BookingOverlapCaption`-Tests; Verdrahtung Task 4 |

## Backlog-Hinweis

Nach Umsetzung: kurze Notiz in `docs/dev/feature-backlog.md` unter „Was Reisen bereits besser kann“. F24 unverändert.
