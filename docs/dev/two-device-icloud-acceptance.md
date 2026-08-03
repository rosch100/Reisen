# Zwei-Geräte-iCloud-Acceptance

Status: **Manuell / bedingt automatisierbar** — Skript vorhanden, Live-Lauf braucht iCloud-Login auf beiden Simulatoren.

## Automatisierbar

Skript (SSOT): [`Scripts/verify-two-device-icloud.sh`](../../Scripts/verify-two-device-icloud.sh)

Voraussetzungen:

1. Zwei Simulatoren gebootet (Default: `iPad Pro 13-inch (M5)` + `iPhone 17 Pro`; Override via `IOS_SIMULATOR_A` / `IOS_SIMULATOR_B`).
2. Auf **beiden** derselbe iCloud-Account (Settings → Apple Account).
3. CloudKit aktiv (kein `REISEN_CLOUDKIT=0` / kein `CI=true` beim Launch).
4. iOS-Projekt generiert (`bash ./Scripts/generate-ios-project.sh`).

Lauf:

```bash
bash ./Scripts/verify-two-device-icloud.sh
```

Gerät A seedet Trip/Bookings/Gap (+ lokales Reminder); Gerät B erwartet Cloud-Daten **ohne** Reminder-Übernahme.

Unit-/In-Process-Abdeckung (ohne Live-iCloud): `HybridTwoDeviceSyncTests`, `CloudKitTwoDeviceVerification` (lokale Hybrid-Store-Semantik).

## Nicht automatisierbar hier

- iCloud-Anmeldung in Simulatoren (Apple-Account, 2FA, System-UI).
- Echtes CloudKit-Push/Import über Apple-Infrastruktur ohne Account.
- Agent-Umgebung ohne vorbereitete iCloud-Sessions → Skript endet typisch mit `noAccount` / Timeout.

## Acceptance-Checkliste (manuell)

1. [ ] Beide Geräte mit gleichem iCloud-Account.
2. [ ] Skript exit 0; Result-JSON `ok: true` auf A und B.
3. [ ] Trip/Booking von A erscheint auf B.
4. [ ] EventKit-Reminder bleibt lokal (nicht auf B gespiegelt).
5. [ ] Cookie/Login-Sessions bleiben gerätegebunden.
