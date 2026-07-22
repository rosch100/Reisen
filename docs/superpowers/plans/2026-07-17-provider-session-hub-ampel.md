# Provider Session Hub & Login-Ampel — Implementation Plan

> **For agentic workers:** Implement task-by-task. Steps use checkbox syntax.

**Goal:** Sidebar-Ampel (grün/rot/grau) + parallele WebView-Sessions für aktivierte Provider.

**Architecture:** `ProviderSessionHub` im Environment; `ProviderSyncContainer` hält SyncViews aller aktivierten Provider wie Browser-Tabs; Sidebar liest Ampel aus Hub.

**Tech Stack:** SwiftUI, WKWebView, `@Observable`, `@AppStorage`, Swift Testing

## Global Constraints

- Ampel: grün=logged in, rot=needs login, grau=disabled
- Nur aktivierte Provider halten WebViews
- Keine Fallbacks/Dummy-Werte; bestehende URL-Heuristik wiederverwenden

---

### Task 1: Traffic-Light-Mapping

- [ ] `ProviderLoginTrafficLight` in ReisenDomain
- [ ] Unit tests

### Task 2: Hub + Environment

- [ ] `ProviderSessionHub` (@Observable)
- [ ] Environment key
- [ ] Bootstrap injection

### Task 3: Parallel Sessions UI

- [ ] `ProviderSyncContainer` mit ZStack/ForEach enabled providers
- [ ] SyncView schreibt Status/WebView/URL in Hub
- [ ] ContentView nutzt Container

### Task 4: Sidebar Ampel

- [ ] Circle in `ProviderSidebarRow` aus Hub + enabled

### Task 5: Verify

- [ ] Domain tests green; App build soweit path
