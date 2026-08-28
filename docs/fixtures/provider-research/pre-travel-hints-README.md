# Pre-travel stay hints — research fixtures

Stay-Detail phrases come from provider reservation-overview payloads. Empty parser
output means no prep-relevant text was visible — not a dummy fallback.

| File | Provider | Notes |
|------|----------|-------|
| `gyg_bookingSummary_redacted.json` | GetYourGuide | Real redacted fixture (existing) |
| `airbnb_stay_hints_synthetic.json` | Airbnb | Live Stay-RO (`house_rules` / `house_manual`); je Item u. a. eigene Bettwäsche + Handtücher |
| `bookingcom_confirmation_hints_synthetic.html` | Booking.com | HotelChainBedLinen + towels/sheets fee |
| `bookingcom_confirmation_policies_de_synthetic.html` | Booking.com | DE Confirm: Ankunft/Ausweis; FAQ+i18n dürfen keine Haustier-Hints erzeugen |
| `check24_hotel_detail_hints_synthetic.html` | Check24 | DE linen/towel phrases |
| `opodo_trip_detail_hints_synthetic.html` | Opodo | EN bed linens not included |
| `traveloka_itinerary_single_hotel_redacted.json` | Traveloka | Live 2026-08-28: `importantNoticePolicies` + `propertyPolicy` (Hausregeln/Dokumente); kein Pet-/Linen-Feld in diesem Konto |

Replace remaining synthetic fixtures with redacted live captures when available; keep parser contracts stable via `sourceKey`.

**Traveloka:** `TravelokaGuestHintMapper` — structured notices like GYG; `propertyPolicy` as Hausregeln; `checkInInstruction` only if `BookingGuestHintPrepKeywords` match. Do not add bare `pet` tokens (ID „Petunjuk“ false-positive).
