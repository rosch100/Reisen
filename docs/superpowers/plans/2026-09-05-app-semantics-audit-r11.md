# App Semantik-Audit R11 Implementation Plan

> Inline (ohne Rückfragen).

**Goal:** Display-Formatierung und Kalender-Defaults auf Hotel-GMT-SSOT bringen (kein Geräte-TZ-Drift; R10-Defaults nicht überschreiben).

1. `TripDateBounds.formattedAbbreviatedRange` → `HotelStayDate.format(..., "d.M.yyyy")`; Bounds weiter über `from(...)`
2. `TripPeriodExpandPrompt.formattedRange`/`message` → `HotelStayDate.format`; ungenutzten `Calendar`-Param entfernen
3. Domain-Test: Default-Range für `HotelStayDate.dateOnly(2026,9,5)` enthält `"5.9"`, nicht Vortag
4. SharedUI-Test: `TripPeriodExpandPrompt.formattedRange` analog
5. `OpenBookingMatching` / `TripBookingAssignment` / `OpenBookingCreateTripAction` / `PasteImportReviewPayload.creating` Defaults → `HotelStayDate.calendar`
6. `SyncProviderBookings` `startOfToday` → `HotelStayDate.calendar`
7. Domain-Tests: Assignment + Sync `startOfToday` behalten Hotel-GMT-Tag
8. Trip-Period-Display (ContentView, TripDetailView, TripDetailIOS, ReisenTab) → `TripDateBounds.formattedAbbreviatedRange(start:end:)` / `HotelStayDate.format`
9. `TripEditorSheet` Persist → `HotelStayDate.dateOnly(fromLocalPickerDate:)` für start/end
10. Spec/Plan R11; kein Commit in diesem Schritt
