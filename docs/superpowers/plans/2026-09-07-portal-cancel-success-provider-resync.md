# Portal-Cancel Success → Provider-Resync Implementation Plan

> **For agentic workers:** Inline execution in this session (user: implement spec).

**Goal:** Nach erkannter Portal-Storno-Completion im Cancel-Sheet still denselben Provider syncen.

**Architecture:** Domain-Detector (Opodo `bereits storniert`) → Sheet sticky Flag + pageText-Probe → `reisenSyncProvider` (SharedUI) → ContentView / RootTabView → `SyncStore.sync` mit `provider_sync_after_cancel`.

**Tech Stack:** Swift, WKWebView, DiagnosticLogger, Swift Testing

## Global Constraints

- Nur Opodo-Marker v1; keine URL-Wildcards
- Kein lokales `cancelled`; kein Safari-Auto-Sync; Busy → skip
- Logging + Domain-Tests; `bash ./Scripts/ci-test.sh`; kein XCUI

## Files

| File | Role |
| --- | --- |
| `Sources/ReisenDomain/Services/PortalCancelCompletionDetector.swift` | Pure Detector |
| `Tests/ReisenDomainTests/PortalCancelCompletionDetectorTests.swift` | Tests |
| `Sources/ReisenSharedUI/ReisenAppNotifications.swift` | `reisenSyncProvider` SSOT |
| `Sources/ReisenProviders/PortalCancelCompletionProbe.swift` | innerText evaluate + log detected |
| `Sources/ReisenProviderSync/PortalCancelProviderResync.swift` | handle notification → sync / busy-skip |
| `Sources/Reisen/App/BookingPortalCancelSheetHost.swift` | Flag + probe + post on disappear |
| `Apps/ReiseniOS/Shared/BookingPortalCancelSheetHostIOS.swift` | same |
| `Sources/Reisen/App/ContentView.swift` | onReceive |
| `Apps/ReiseniOS/Shared/RootTabView.swift` | onReceive (Private) |

### Task 1: Detector + Tests + Notifications + Probe + Resync + Wire

- [x] Domain Detector + Tests
- [x] SharedUI notification
- [x] Probe + Resync helper
- [x] Sheet hosts + listeners
- [x] `ci-test.sh`
