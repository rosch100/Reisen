import SwiftUI
import SwiftData
#if REISEN_PROVIDER_SYNC
import WebKit
#endif

import ReisenAppCore
import ReisenPasteImport
import ReisenSharedUI
import ReisenDomain
import ReisenData
import ReisenDiagnostics
#if REISEN_PROVIDER_SYNC
import ReisenProviders
#endif

struct RootTabView: View {
    let onResetLocalStores: () -> Void
    let onWipeCloudAndReset: () -> Void

    @State private var sessionChromeEpoch = 0
    @State private var providerEnableEpoch = 0
    @State private var showProviderSetup = false
    @State private var didRecordProviderSetupPresented = false
    @State private var selectedTab: AppTab = .reisen
    @State private var selectedTripID: UUID?
    @State private var selectedOpenBookingID: UUID?
    @State private var compactPushOpenBookingID: UUID?
    @State private var focusTripBookingID: UUID?
    @State private var compactPushTripID: UUID?
    @State private var pasteImport = PasteImportSession()
    #if REISEN_PROVIDER_SYNC
    @State private var installedProviderIDs: Set<ProviderID> = []
    #endif
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext

    private enum AppTab: Hashable {
        case reisen, offen
        #if REISEN_PROVIDER_SYNC
        case sync
        #endif
        case mehr
    }

    #if REISEN_PROVIDER_SYNC
    private var nativeAppPresenceReader: ProviderNativeAppPresenceReader {
        ProviderNativeAppPresenceReader(isInstalled: { installedProviderIDs.contains($0) })
    }
    #endif

    @ViewBuilder
    var body: some View {
        PasteImportHost(
            session: pasteImport,
            entry: { pasteImportEntry },
            onSelectSavedBooking: selectPasteImportBooking
        ) {
            tabsWithSessionProbe
        }
        .sheet(isPresented: $showProviderSetup) {
            ProviderFirstLaunchSetupSheet(
                onContinue: completeProviderSetup,
                onLater: deferProviderSetup
            )
        }
    }

    @ViewBuilder
    private var tabsWithSessionProbe: some View {
        ZStack {
            tabs
                .tabViewStyle(.sidebarAdaptable)
                #if REISEN_PROVIDER_SYNC
                .environment(\.providerNativeAppPresence, nativeAppPresenceReader)
                .environment(\.providerEnableEpoch, providerEnableEpoch)
                #endif

            #if REISEN_PROVIDER_SYNC
            SyncBackgroundSessionProbe(
                onSessionChanged: {
                    sessionChromeEpoch &+= 1
                }
            )
            .frame(width: 1, height: 1)
            .opacity(0.01)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            #endif
        }
        .onAppear {
            presentProviderSetupIfNeeded()
            #if REISEN_PROVIDER_SYNC
            refreshProviderAppPresence()
            #endif
        }
        #if REISEN_PROVIDER_SYNC
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                refreshProviderAppPresence()
                presentProviderSetupIfNeeded()
            }
        }
        .onProviderEnabledChange(bump: $providerEnableEpoch) {
            presentProviderSetupIfNeeded()
        }
        #endif
    }

    #if REISEN_PROVIDER_SYNC
    private func refreshProviderAppPresence() {
        installedProviderIDs = Set(ProviderNativeAppPresence.installedProviderIDs())
        _ = ProviderNativeAppPresence.applyAutoEnableIfNeeded()
    }
    #endif

    private func presentProviderSetupIfNeeded() {
        guard ProviderFirstLaunchSetup.shouldPresent() else { return }
        guard !showProviderSetup else { return }
        showProviderSetup = true
        recordProviderSetupPresentedIfNeeded(reason: "fresh_launch")
    }

    private func presentProviderSetupFromReopen() {
        showProviderSetup = true
        recordProviderSetupDiagnostic(
            event: "provider_setup_presented",
            result: .started,
            reason: "reopen"
        )
    }

    private func completeProviderSetup(enabledIDs: Set<ProviderID>) {
        let defaults = AppSettingsDefaults.current
        ProviderFirstLaunchSetup.applySelection(enabledIDs: enabledIDs, defaults: defaults)
        ProviderEnabledChange.notify()
        ProviderFirstLaunchSetup.markCompleted(defaults: defaults)
        showProviderSetup = false
        #if REISEN_PROVIDER_SYNC
        selectedTab = .sync
        #endif
        recordProviderSetupDiagnostic(
            event: "provider_setup_completed",
            result: .succeeded,
            reason: "continue_count_\(enabledIDs.count)"
        )
    }

    private func deferProviderSetup() {
        ProviderFirstLaunchSetup.markDeferred()
        showProviderSetup = false
        recordProviderSetupDiagnostic(
            event: "provider_setup_deferred",
            result: .cancelled,
            reason: "later"
        )
    }

    private func recordProviderSetupPresentedIfNeeded(reason: String) {
        guard !didRecordProviderSetupPresented else { return }
        didRecordProviderSetupPresented = true
        recordProviderSetupDiagnostic(
            event: "provider_setup_presented",
            result: .started,
            reason: reason
        )
    }

    private func recordProviderSetupDiagnostic(
        event: String,
        result: DiagnosticResult,
        reason: String
    ) {
        let context = DiagnosticContext(
            runID: UUID(),
            providerID: .manual,
            operation: "provider_first_launch_setup"
        )
        Task {
            await DiagnosticLogger.shared.record(
                DiagnosticEvent(
                    context: context,
                    component: "ProviderFirstLaunchSetup",
                    phase: "setup",
                    event: event,
                    result: result,
                    reason: reason
                )
            )
        }
    }

    private func focusCreatedTrip(_ tripID: UUID) {
        selectedTripID = tripID
        selectedTab = .reisen
    }

    /// Nach Review-Sichern: compact → Detail, split → Selection.
    private func selectPasteImportBooking(_ bookingID: UUID) {
        let tripID = try? modelContext.fetch(
            FetchDescriptor<SDBooking>(predicate: #Predicate { $0.id == bookingID })
        ).first?.trip?.id

        if let tripID {
            selectedTripID = tripID
            compactPushTripID = tripID
            focusTripBookingID = bookingID
            selectedTab = .reisen
            return
        }
        selectedOpenBookingID = bookingID
        compactPushOpenBookingID = bookingID
        selectedTab = .offen
    }

    /// Drop und „Öffnen mit“ nutzen den sichtbaren Tab, nicht einen anderen Reise-Kontext.
    private var pasteImportEntry: PasteImportEntry {
        switch selectedTab {
        case .reisen:
            return .trip(selectedTripID)
        case .offen:
            return .open
        #if REISEN_PROVIDER_SYNC
        case .sync:
            return .open
        #endif
        case .mehr:
            return .open
        }
    }

    private var tabs: some View {
        TabView(selection: $selectedTab) {
            #if REISEN_PROVIDER_SYNC
            ReisenTab(
                sessionChromeEpoch: $sessionChromeEpoch,
                selectedTripID: $selectedTripID,
                compactPushTripID: $compactPushTripID,
                focusBookingID: $focusTripBookingID,
                pasteImport: pasteImport,
                onOpenSync: { selectedTab = .sync }
            )
            .tabItem { Label(L10n.string(.tabTrips), systemImage: "airplane") }
            .tag(AppTab.reisen)
            #else
            ReisenTab(
                sessionChromeEpoch: $sessionChromeEpoch,
                selectedTripID: $selectedTripID,
                compactPushTripID: $compactPushTripID,
                focusBookingID: $focusTripBookingID,
                pasteImport: pasteImport
            )
            .tabItem { Label(L10n.string(.tabTrips), systemImage: "airplane") }
            .tag(AppTab.reisen)
            #endif

            #if REISEN_PROVIDER_SYNC
            OffenTab(
                sessionChromeEpoch: $sessionChromeEpoch,
                selectedBookingID: $selectedOpenBookingID,
                compactPushBookingID: $compactPushOpenBookingID,
                pasteImport: pasteImport,
                onTripCreated: focusCreatedTrip,
                onOpenSync: { selectedTab = .sync }
            )
            .tabItem { Label(L10n.string(.tabOpen), systemImage: "list.bullet.rectangle") }
            .tag(AppTab.offen)
            #else
            OffenTab(
                sessionChromeEpoch: $sessionChromeEpoch,
                selectedBookingID: $selectedOpenBookingID,
                compactPushBookingID: $compactPushOpenBookingID,
                pasteImport: pasteImport,
                onTripCreated: focusCreatedTrip
            )
            .tabItem { Label(L10n.string(.tabOpen), systemImage: "list.bullet.rectangle") }
            .tag(AppTab.offen)
            #endif

            #if REISEN_PROVIDER_SYNC
            SyncTab(
                sessionChromeEpoch: $sessionChromeEpoch,
                isSelected: selectedTab == .sync,
                onOpenSettings: { selectedTab = .mehr },
                onReopenProviderSetup: presentProviderSetupFromReopen
            )
                .tabItem { Label(L10n.string(.tabSync), systemImage: "arrow.triangle.2.circlepath") }
                .tag(AppTab.sync)
            #endif

            MoreTab(
                onResetLocalStores: onResetLocalStores,
                onWipeCloudAndReset: onWipeCloudAndReset
            )
                .tabItem { Label(L10n.string(.tabMore), systemImage: "ellipsis.circle") }
                .tag(AppTab.mehr)
        }
    }
}
