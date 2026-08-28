# Pre-travel stay hints — research fixtures

Live HAR capture was not available in the agent worktree. Synthetic fixtures encode the
prep-relevant phrases documented in the implementation plan so parsers can be tested without PII.

| File | Provider | Notes |
|------|----------|-------|
| `gyg_bookingSummary_redacted.json` | GetYourGuide | Real redacted fixture (existing) |
| `airbnb_stay_hints_synthetic.json` | Airbnb | Essentials absent + towels/linens house rule |
| `bookingcom_confirmation_hints_synthetic.html` | Booking.com | HotelChainBedLinen + towels/sheets fee |
| `bookingcom_confirmation_policies_de_synthetic.html` | Booking.com | DE Confirm: Ankunft/Ausweis; FAQ+i18n dürfen keine Haustier-Hints erzeugen |
| `check24_hotel_detail_hints_synthetic.html` | Check24 | DE linen/towel phrases |
| `opodo_trip_detail_hints_synthetic.html` | Opodo | EN bed linens not included |

Replace with redacted live captures when available; keep parser contracts stable via `sourceKey`.
