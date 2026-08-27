import SwiftUI
import SwiftData
import CloudKit

import ReisenDomain
import ReisenData
import ReisenAppCore

public struct SettingsView: View {
    private let showsDataManagement: Bool
    private let onResetLocalStores: (() -> Void)?
    private let onWipeCloudAndReset: (() -> Void)?

    public init(
        showsDataManagement: Bool = false,
        onResetLocalStores: (() -> Void)? = nil,
        onWipeCloudAndReset: (() -> Void)? = nil
    ) {
        self.showsDataManagement = showsDataManagement
        self.onResetLocalStores = onResetLocalStores
        self.onWipeCloudAndReset = onWipeCloudAndReset
    }

    @AppStorage(AppSettingsKeys.notificationEnabled) private var notificationEnabled: Bool = true
    @AppStorage(AppSettingsKeys.eventKitEnabled) private var eventKitEnabled: Bool = false
    @AppStorage(AppSettingsKeys.calendarTitle) private var calendarTitle: String = "Reisen"
    @AppStorage(AppSettingsKeys.reminderCalendarTitle) private var reminderCalendarTitle: String = "Reisen"
    @AppStorage(AppSettingsKeys.leadTimesDays) private var leadTimesDaysRaw: String = "7,3,1"
    @AppStorage(AppSettingsKeys.calendarTripTimesEnabled) private var calendarTripTimesEnabled: Bool = false
    @AppStorage(AppSettingsKeys.calendarFlightTimesEnabled) private var calendarFlightTimesEnabled: Bool = false
    @AppStorage(AppSettingsKeys.calendarHotelStaysEnabled) private var calendarHotelStaysEnabled: Bool = false
    @AppStorage(AppSettingsKeys.eventCalendarCreateIfMissing) private var eventCalendarCreateIfMissing: Bool = false
    @AppStorage(AppSettingsKeys.reminderCalendarCreateIfMissing) private var reminderCalendarCreateIfMissing: Bool = false
    @AppStorage(AppSettingsKeys.calendarTitleMode) private var calendarTitleModeRaw: String = CalendarTitleMode.tripTitle.rawValue
    @AppStorage(AppSettingsKeys.rememberLoginAutomatically) private var rememberLoginAutomatically: Bool = false
    @AppStorage(AppSettingsKeys.reportErrorsToGitHub) private var reportErrorsToGitHub: Bool = false

    @State private var eventCalendarNames: [String] = []
    @State private var reminderCalendarNames: [String] = []
    @State private var isLoadingCalendarNames = false
    @State private var calendarNamesError: String?
    @State private var calendarNamesPrivacyPanes: [PrivacySettingPane] = []
    @State private var calendarNamesReloadToken = UUID()
    @State private var showLocalResetConfirm = false
    @State private var showCloudWipeConfirm = false
    @State private var cloudAccountStatus: CKAccountStatus?
    @State private var cloudAccountStatusError: String?
    @State private var feedbackText = ""

    private let newCalendarTag = "__NEUER_KALENDER__"

    private var leadTimesDays: [Int] {
        LeadTimesDays.normalized(
            leadTimesDaysRaw
                .split(separator: ",")
                .compactMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
        )
    }

    private var leadTimesDaysDisplayText: String {
        leadTimesDaysRaw
            .split(separator: ",")
            .compactMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
            .filter { $0 > 0 }
            .map(String.init)
            .joined(separator: ", ")
    }

    public var body: some View {
        Form {
            ProviderEnabledSettingsSection()

            Section {
                Toggle("Passwort nach Login speichern", isOn: $rememberLoginAutomatically)
            } header: {
                Text("Provider-Anmeldung")
            } footer: {
                Text(
                    "Speichert E-Mail und Kennwort nach erfolgreichem Passwort-Login automatisch in Reisen. "
                        + "Apple-, Passkey- und OAuth-Anmeldungen werden nicht als Kennwort gespeichert."
                )
            }

            Section {
                Toggle("Lokale Benachrichtigungen", isOn: $notificationEnabled)
            } header: {
                Text("Erinnerungen")
            } footer: {
                Text("Plant Erinnerungen vor Stornofristen über das Mitteilungszentrum.")
            }

            Section {
                Toggle("Apple Kalender", isOn: $eventKitEnabled)

                if eventKitEnabled {
                    Picker(
                        "Kalender-Strategie",
                        selection: $calendarTitleModeRaw
                    ) {
                        Text("Pro Reise (Reisenname)").tag(CalendarTitleMode.tripTitle.rawValue)
                        Text("Global („Reisen“)").tag(CalendarTitleMode.fixed.rawValue)
                    }
                    .pickerStyle(.segmented)

                    if CalendarTitleMode(rawValue: calendarTitleModeRaw) == .tripTitle {
                        Toggle("Event-Kalender automatisch anlegen", isOn: $eventCalendarCreateIfMissing)
                        Toggle("Reminder-Liste automatisch anlegen", isOn: $reminderCalendarCreateIfMissing)
                    }

                    if isLoadingCalendarNames {
                        ProgressView("Kalender werden geladen…")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        if CalendarTitleMode(rawValue: calendarTitleModeRaw) == .fixed {
                            Picker("Kalender", selection: eventCalendarPickerSelection) {
                                ForEach(eventCalendarPickerOptions, id: \.self) { name in
                                    Text(name == newCalendarTag ? "Neuen Kalender anlegen…" : name).tag(name)
                                }
                            }
                            .pickerStyle(.menu)

                            if eventCalendarCreateIfMissing {
                                TextField("Neuer Kalendername", text: $calendarTitle)
                                    .textFieldStyle(.roundedBorder)
                            }

                            Divider()

                            Picker("Reminder-Liste", selection: reminderCalendarPickerSelection) {
                                ForEach(reminderCalendarPickerOptions, id: \.self) { name in
                                    Text(name == newCalendarTag ? "Neue Reminder-Liste anlegen…" : name).tag(name)
                                }
                            }
                            .pickerStyle(.menu)

                            if reminderCalendarCreateIfMissing {
                                TextField("Neue Reminder-Liste", text: $reminderCalendarTitle)
                                    .textFieldStyle(.roundedBorder)
                            }

                            if let calendarNamesError {
                                Text(calendarNamesError)
                                    .foregroundStyle(.secondary)

                                ForEach(calendarNamesPrivacyPanes, id: \.self) { pane in
                                    OpenPrivacySettingsButton(pane: pane)
                                }

                                Button("Erneut laden") {
                                    calendarNamesReloadToken = UUID()
                                }
                            }
                        }
                    }
                }
            } header: {
                Text("Kalender")
            } footer: {
                Text("Legt Termine für Stornofristen im angegebenen Kalender an. Optional: Reise- und Flugzeiten.")
            }

            Section {
                Toggle("Reisebeginn/-ende eintragen", isOn: $calendarTripTimesEnabled)
                    .disabled(!eventKitEnabled)
                    .help(eventKitEnabled ? "Schreibt Reisebeginn und -ende als Kalender-Einträge." : "Aktiviere zuerst „Apple Kalender“.")

                Toggle("Flugabflug/-ankunft eintragen", isOn: $calendarFlightTimesEnabled)
                    .disabled(!eventKitEnabled)
                    .help(eventKitEnabled ? "Schreibt Abflug und Ankunft der Flug-Buchungen als Kalender-Einträge." : "Aktiviere zuerst „Apple Kalender“.")

                Toggle("Hotelaufenthalte eintragen", isOn: $calendarHotelStaysEnabled)
                    .disabled(!eventKitEnabled)
                    .help(eventKitEnabled ? "Schreibt jede Hotelbuchung als ganztägigen Eintrag in deinen Kalender." : "Aktiviere zuerst „Apple Kalender“.")
            } header: {
                Text("Reisezeiten")
            } footer: {
                Text("Zeitzonen werden aus vorhandenen Zeit-/Offsets abgeleitet.")
            }

            Section {
                TextField("Vorläufe in Tagen", text: $leadTimesDaysRaw)
                    .textFieldStyle(.roundedBorder)
                    .help("Kommagetrennte Tage vor der Stornofrist, z. B. 7,3,1")

                if leadTimesDays.isEmpty {
                    Text("Keine gültigen Vorläufe. Beispiel: 7,3,1")
                        .foregroundStyle(.secondary)
                } else {
                    Text("Erinnerungen \(leadTimesDaysDisplayText) Tage vor der Frist.")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Vorlaufzeiten")
            } footer: {
                Text("Beispiel: 7,3,1 — Erinnerungen 7, 3 und 1 Tag vor der Frist.")
            }

            Section {
                Link(Self.legalPrivacyTitle, destination: LegalURLs.privacyPolicy)
                Link(Self.legalSupportTitle, destination: LegalURLs.support)
            } header: {
                Text(Self.legalSectionTitle)
            } footer: {
                Text(Self.legalSectionFooter)
            }

            Section {
                Label("Daten synchronisieren über iCloud", systemImage: "icloud")
                Text(cloudAccountStatusText)
                    .font(.footnote)
                    .foregroundStyle(cloudAccountStatusIsError ? .red : .secondary)
                Text("Reisen, Buchungen und Lücken werden über den Container „\(PersistenceBootstrap.cloudKitContainerID)“ zwischen iPhone, iPad und Mac geteilt. Kalender-Links und Erinnerungs-IDs bleiben gerätebezogen.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } header: {
                Text("iCloud")
            } footer: {
                Text(cloudAccountFooterText)
            }

            Section {
                if GitHubIssueToken.isEmbedded {
                    Toggle("Fehler automatisch als öffentliches Issue senden", isOn: $reportErrorsToGitHub)
                }
                TextEditor(text: $feedbackText)
                    .frame(minHeight: 80)
                PublicGitHubIssueReportActions(
                    feedbackMessage: feedbackText,
                    onReported: { feedbackText = "" }
                )
                Link("Alle öffentlichen Issues", destination: GitHubRepository.issuesListURL)
            } header: {
                Text("Feedback")
            } footer: {
                Text(
                    GitHubIssueToken.isEmbedded
                        ? "Feedback legt ein öffentliches GitHub-Issue an. "
                            + "Automatische Fehler-Issues nur mit dem Schalter oben; ohne Sync-Log, "
                            + "ohne Login-/Datenschutz-Meldungen. Repo: github.com/\(GitHubRepository.publicPath)."
                        : "„In GitHub veröffentlichen…“ öffnet ein neues Issue in Safari mit vorausgefülltem Text. "
                            + "Du sendest mit deinem GitHub-Konto. Repo: github.com/\(GitHubRepository.publicPath)."
                )
            }

            if showsDataManagement {
                Section {
                    Button("Lokale Stores zurücksetzen…", role: .destructive) {
                        showLocalResetConfirm = true
                    }
                    Button("Auch iCloud-Daten leeren…", role: .destructive) {
                        showCloudWipeConfirm = true
                    }
                } header: {
                    Text("Daten")
                } footer: {
                    Text("Lokales Zurücksetzen entfernt nur Store-Dateien auf diesem Gerät. iCloud kann Daten danach erneut laden. „Auch iCloud-Daten leeren“ löscht synchronisierte Datensätze geräteübergreifend.")
                }
            }
        }
#if os(macOS)
        .formStyle(.grouped)
        .padding()
        .frame(width: 520, height: 620)
#endif
        .confirmationDialog(
            "Lokale Stores zurücksetzen?",
            isPresented: $showLocalResetConfirm,
            titleVisibility: .visible
        ) {
            Button("Lokale Stores löschen", role: .destructive) {
                onResetLocalStores?()
            }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Lokale Dateien werden gelöscht. Bei aktivem iCloud Sync können Daten erneut geladen werden.")
        }
        .confirmationDialog(
            "iCloud-Daten wirklich leeren?",
            isPresented: $showCloudWipeConfirm,
            titleVisibility: .visible
        ) {
            Button("iCloud und lokal leeren", role: .destructive) {
                onWipeCloudAndReset?()
            }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Synchronisierte Reisen und Buchungen werden gelöscht und die Löschung über iCloud übertragen.")
        }
        .task(id: eventKitEnabled) {
            guard eventKitEnabled else { return }
            guard CalendarTitleMode(rawValue: calendarTitleModeRaw) == .fixed else { return }
            await loadCalendarNamesIfNeeded(forceReload: false)
        }
        .task(id: calendarNamesReloadToken) {
            guard eventKitEnabled else { return }
            guard CalendarTitleMode(rawValue: calendarTitleModeRaw) == .fixed else { return }
            await loadCalendarNamesIfNeeded(forceReload: true)
        }
        .task {
            await refreshCloudAccountStatus()
        }
    }

    private var cloudAccountStatusText: String {
        if let cloudAccountStatusError {
            return cloudAccountStatusError
        }
        switch cloudAccountStatus {
        case .none:
            return "iCloud-Status wird geprüft…"
        case .some(.available):
            return "iCloud-Account verfügbar — Sync aktiv, sofern nicht per Umgebung deaktiviert."
        case .some(.noAccount):
            return "Kein iCloud-Account angemeldet. Sync-Daten bleiben nur lokal auf diesem Gerät."
        case .some(.restricted):
            return "iCloud ist eingeschränkt (z. B. Screen Time / MDM). Sync ist nicht verfügbar."
        case .some(.couldNotDetermine):
            return "iCloud-Status konnte nicht ermittelt werden."
        case .some(.temporarilyUnavailable):
            return "iCloud ist vorübergehend nicht erreichbar."
        case .some(let other):
            return "iCloud-Status: \(String(describing: other))."
        }
    }

    private var cloudAccountStatusIsError: Bool {
        switch cloudAccountStatus {
        case .some(.noAccount), .some(.restricted), .some(.couldNotDetermine), .some(.temporarilyUnavailable):
            return true
        default:
            return cloudAccountStatusError != nil
        }
    }

    private var cloudAccountFooterText: String {
        switch cloudAccountStatus {
        case .some(.noAccount):
            return "Melde dich in den Systemeinstellungen bei iCloud an, damit Reisen zwischen Geräten synchronisiert."
        case .some(.restricted), .some(.temporarilyUnavailable):
            return "Behebe den iCloud-Zugang; bis dahin werden keine Cloud-Änderungen geladen oder geschrieben."
        default:
            return "Ohne iCloud-Account erscheinen Sync-Daten nur lokal auf diesem Gerät."
        }
    }

    @MainActor
    private func refreshCloudAccountStatus() async {
        cloudAccountStatusError = nil
        let status = await PersistenceBootstrap.fetchCloudKitAccountStatus()
        cloudAccountStatus = status
        if status == .couldNotDetermine {
            cloudAccountStatusError = nil
        }
    }

    private var eventCalendarPickerSelection: Binding<String> {
        Binding(
            get: {
                eventCalendarCreateIfMissing ? newCalendarTag : calendarTitle
            },
            set: { newValue in
                if newValue == newCalendarTag {
                    eventCalendarCreateIfMissing = true
                } else {
                    eventCalendarCreateIfMissing = false
                    calendarTitle = newValue
                }
            }
        )
    }

    private var reminderCalendarPickerSelection: Binding<String> {
        Binding(
            get: {
                reminderCalendarCreateIfMissing ? newCalendarTag : reminderCalendarTitle
            },
            set: { newValue in
                if newValue == newCalendarTag {
                    reminderCalendarCreateIfMissing = true
                } else {
                    reminderCalendarCreateIfMissing = false
                    reminderCalendarTitle = newValue
                }
            }
        )
    }

    private var eventCalendarPickerOptions: [String] {
        var options = eventCalendarNames
        if !options.contains(calendarTitle) { options.insert(calendarTitle, at: 0) }
        if !options.contains(newCalendarTag) { options.append(newCalendarTag) }
        return options
    }

    private var reminderCalendarPickerOptions: [String] {
        var options = reminderCalendarNames
        if !options.contains(reminderCalendarTitle) { options.insert(reminderCalendarTitle, at: 0) }
        if !options.contains(newCalendarTag) { options.append(newCalendarTag) }
        return options
    }

    @MainActor
    private func loadCalendarNamesIfNeeded(forceReload: Bool) async {
        guard forceReload || (eventCalendarNames.isEmpty && reminderCalendarNames.isEmpty && !isLoadingCalendarNames) else {
            return
        }
        guard CalendarTitleMode(rawValue: calendarTitleModeRaw) == .fixed else { return }

        isLoadingCalendarNames = true
        calendarNamesError = nil
        calendarNamesPrivacyPanes = []

        if forceReload {
            eventCalendarNames = []
            reminderCalendarNames = []
        }

        let bridge = LocalEventKitBridge()
        var errors: [String] = []
        var panes: [PrivacySettingPane] = []

        do {
            eventCalendarNames = try await bridge.fetchEventCalendarTitles()
        } catch {
            recordCalendarNameFailure(error, errors: &errors, panes: &panes)
        }

        do {
            reminderCalendarNames = try await bridge.fetchReminderCalendarTitles()
        } catch {
            recordCalendarNameFailure(error, errors: &errors, panes: &panes)
        }

        if !errors.isEmpty {
            calendarNamesError = errors.joined(separator: " ")
            calendarNamesPrivacyPanes = panes
        }

        isLoadingCalendarNames = false
    }

    private func recordCalendarNameFailure(
        _ error: Error,
        errors: inout [String],
        panes: inout [PrivacySettingPane]
    ) {
        errors.append(error.localizedDescription)
        if let pane = PrivacyAccessDenial.pane(from: error), !panes.contains(pane) {
            panes.append(pane)
        }
    }

    private static var usesGermanLegalCopy: Bool {
        Locale.current.reisenPrefersGerman
    }

    private static var legalPrivacyTitle: String {
        usesGermanLegalCopy ? "Datenschutzerklärung" : "Privacy Policy"
    }

    private static var legalSupportTitle: String {
        "Support"
    }

    private static var legalSectionTitle: String {
        usesGermanLegalCopy ? "Datenschutz & Support" : "Privacy & Support"
    }

    private static var legalSectionFooter: String {
        usesGermanLegalCopy
            ? "Beschreibt Provider-Logins, iCloud, Kalender und lokale Speicherung."
            : "Describes provider logins, iCloud, calendar, and local storage."
    }
}

