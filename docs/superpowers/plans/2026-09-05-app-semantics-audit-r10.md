# App Semantik-Audit R10 Implementation Plan

> Inline (ohne Rückfragen).

**Goal:** Auth-/Offset-/Hotel-Kalender-Residuals nach R9 schließen.

1. Booking Catalog: `sessionTokensMissing` fail-closed vor HTML-Fallback + Test
2. Opodo `parseISODate`: Epoch → `hotelOffsetSeconds` nil + Test
3. TripDateBounds / TripBookingDateWindow / TripPeriodExpandOnAssign: Default `HotelStayDate.calendar` + Pacific-Regression
4. ci-test + codereview + PR + Merge
5. R11 frische Analyse (Loop)
