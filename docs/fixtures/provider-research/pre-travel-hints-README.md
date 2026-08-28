# Pre-travel stay hints — research fixtures

| File | Provider | Notes |
|------|----------|-------|
| `gyg_bookingSummary_redacted.json` | GetYourGuide | Real redacted fixture (existing) |
| `airbnb_stay_hints_synthetic.json` | Airbnb | Essentials absent + towels/linens house rule |
| `bookingcom_confirmation_hints_synthetic.html` | Booking.com | HotelChainBedLinen + towels/sheets fee |
| `check24_hotel_detail_hints_synthetic.html` | Check24 | DE linen/towel phrases |
| `opodo_trip_detail_hints_synthetic.html` | Opodo | EN bed linens not included |
| `traveloka_itinerary_single_hotel_redacted.json` | Traveloka | Live 2026-08-28: `importantNoticePolicies` + `propertyPolicy` (Hausregeln/Dokumente); kein Pet-/Linen-Feld in diesem Konto |

Replace remaining synthetic fixtures with redacted live captures when available; keep parser contracts stable via `sourceKey`.

**Traveloka:** `TravelokaGuestHintMapper` — structured notices like GYG; `propertyPolicy` as Hausregeln; `checkInInstruction` only if `BookingGuestHintPrepKeywords` match. Do not add bare `pet` tokens (ID „Petunjuk“ false-positive).
