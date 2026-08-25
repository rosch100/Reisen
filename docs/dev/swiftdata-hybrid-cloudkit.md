# SwiftData Hybrid Store + CloudKit

## Stores

| Configuration | File | CloudKit | Models |
|---------------|------|----------|--------|
| `reisen-cloud` | `Application Support/Reisen/ReisenCloud.sqlite` | `.private(iCloud.de.roschmac.Reisen)` | Trips, Bookings, Gaps, Deadlines, Rates, Passengers, RoomItems, Baggage |
| `reisen-local` | `Application Support/Reisen/ReisenLocal.sqlite` | `.none` | `SDReminder`, `SDCalendarEventLink`, `SDCancellationDeadlineLink` |

CloudKit is disabled when `REISEN_CLOUDKIT=0`, `CI=true`, or an XCTest host is detected.

## Migration plan (intentional empty stages)

`ReisenMigrationPlan.stages` is **empty on purpose**. Historical `VersionedSchema` entries (V1…V6) share the same `@Model` types as V7. Registering them with `Schema(versionedSchema:)` / a multi-version `SchemaMigrationPlan` aborts at runtime with:

`Duplicate version checksums detected` (ObjC exception, not catchable as Swift `Error`).

Instead:

1. Open containers with a non-versioned `Schema(ReisenSchemaV8.models)`.
2. One-time rewrite of legacy `ReisenData.sqlite` → hybrid cloud/local via `migrateLegacyMonolithicStoreIfNeeded()`.
3. On incompatible leftover stores: wipe store files once and retry.

## Side effects after CloudKit import

EventKit links and notification IDs stay device-local. After remote merges (`NSPersistentStoreRemoteChange`) and on app activation, `SyncStore.rebuildLocalSideEffects` rebuilds calendars/reminders from the synced domain data.

## Reset semantics

- **Local reset:** delete store files; CloudKit may re-download syncable entities.
- **Cloud + local (store ready):** `wipeSyncedEntities` → wait for CloudKit export (timeout) → delete store files → reopen.
- **Cloud + local (store failed to open):** reset store files → reopen → wait for CloudKit import → `wipeSyncedEntities` → wait for export → stay ready.

## Two-device iCloud verification

### Automated contract (CI)

`Tests/ReisenDataTests/HybridTwoDeviceSyncTests.swift` opens two dual-store containers that share one cloud SQLite file and use separate local files. Asserts:

- Trip / Bookings / Gap are visible on device B
- `SDReminder` (local) stays only on device A

Run via `bash ./Scripts/ci-test.sh`.

### Live CloudKit (two simulators)

SSOT script:

```bash
bash ./Scripts/verify-two-device-icloud.sh
```

Defaults:

| Env | Default |
|-----|---------|
| `IOS_SIMULATOR_A` | `iPad Pro 13-inch (M5)` |
| `IOS_SIMULATOR_B` | `iPhone 17 Pro` |

**Requirements**

1. Same iCloud account signed in on **both** simulators (Settings → Apple Account). Without this the seed result is `"accountStatus": "noAccount"` / `ok: false`.
2. Do **not** set `REISEN_CLOUDKIT=0` or `CI=true` for the launched app processes (the script clears them for the build/launch path).
3. Network access for CloudKit.

The hybrid store contract (cloud syncs, local does not) is covered in CI without an iCloud login. The live script is the remaining end-to-end CloudKit proof.

**What the script does**

1. Builds/installs `ReiseniOS` on A and B.
2. Launches A with `REISEN_VERIFY_SEED=1` → seeds fixed Trip/Bookings/Gap + device-local Reminder, waits for CloudKit export, writes `verify-two-device-result.json`.
3. Launches B with `REISEN_VERIFY_EXPECT=1` → polls CloudKit import for the seeded IDs, asserts Reminder is absent, writes result JSON.
4. Exits `0` only if both results have `"ok": true`.

Implementation: `CloudKitTwoDeviceVerification` in `Sources/ReisenData/Verification/`.

### Manual checklist (device + Mac)

1. Same iCloud account on both devices; CloudKit enabled.
2. Device A: create a trip, assign a booking, edit a gap → save.
3. Device B: wait for merge (foreground / relaunch).
4. Expect trip, booking assignment, and gap on B.
5. Device B: change trip title → verify update on A.
6. Confirm EventKit links / reminder IDs stay local and are rebuilt after import.
