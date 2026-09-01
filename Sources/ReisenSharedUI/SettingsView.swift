import SwiftUI
import SwiftData
import CloudKit

import ReisenDomain
import ReisenData
import ReisenAppCore

public struct SettingsView: View {
    private let showsProviderSyncSettings: Bool
    private let showsDataManagement: Bool
    private let onResetLocalStores: (() -> Void)?
    private let onWipeCloudAndReset: (() -> Void)?

    public init(
        showsProviderSyncSettings: Bool = false,
        showsDataManagement: Bool = false,
        onResetLocalStores: (() -> Void)? = nil,
        onWipeCloudAndReset: (() -> Void)? = nil
    ) {
        self.showsProviderSyncSettings = showsProviderSyncSettings
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
    @AppStorage(AppSettingsKeys.feedbackGitHubUsername) private var feedbackGitHubUsername = ""
    @AppStorage(AppSettingsKeys.preferredCurrencyCode) private var preferredCurrencyCode: String = ""
    @AppStorage(AppSettingsKeys.convertAmountsToPreferredCurrency) private var convertAmountsToPreferredCurrency: Bool = false

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

    private var preferredCurrencyBinding: Binding<String> {
        Binding(
            get: {
                preferredCurrencyCode.isEmpty
                    ? AppSettingsKeys.preferredCurrency()
                    : preferredCurrencyCode
            },
            set: { newValue in
                preferredCurrencyCode = newValue
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .uppercased()
            }
        )
    }

    private var preferredCurrencyPickerCodes: [String] {
        PreferredCurrencyOptions.codes(including: preferredCurrencyBinding.wrappedValue)
    }

    public var body: some View {
        Form {
            if showsProviderSyncSettings {
                ProviderEnabledSettingsSection()

                Section {
                    Toggle(L10n.string(.settingsRememberPasswordToggle), isOn: $rememberLoginAutomatically)
                } header: {
                    Text(L10n.string(.settingsProviderLogin))
                } footer: {
                    Text(L10n.string(.settingsRememberPasswordFooter))
                }
            }

            Section {
                Toggle(L10n.string(.settingsLocalNotifications), isOn: $notificationEnabled)
            } header: {
                Text(L10n.string(.settingsReminders))
            } footer: {
                Text(L10n.string(.settingsRemindersFooter))
            }

            Section {
                Toggle(L10n.string(.settingsCurrencyConvertToggle), isOn: $convertAmountsToPreferredCurrency)
                if convertAmountsToPreferredCurrency {
                    Picker(L10n.string(.settingsCurrencyPreferred), selection: preferredCurrencyBinding) {
                        ForEach(preferredCurrencyPickerCodes, id: \.self) { code in
                            Text(PreferredCurrencyOptions.displayName(for: code)).tag(code)
                        }
                    }
                    #if os(macOS)
                    .pickerStyle(.menu)
                    #else
                    .pickerStyle(.navigationLink)
                    #endif
                }
            } header: {
                Text(L10n.string(.settingsCurrencySection))
            } footer: {
                Text(L10n.string(.settingsCurrencyFooter))
            }

            Section {
                Toggle(L10n.string(.settingsAppleCalendar), isOn: $eventKitEnabled)

                if eventKitEnabled {
                    Picker(
                        L10n.string(.settingsCalendarStrategy),
                        selection: $calendarTitleModeRaw
                    ) {
                        Text(L10n.string(.settingsCalendarTitleTrip)).tag(CalendarTitleMode.tripTitle.rawValue)
                        Text(L10n.string(.settingsCalendarTitleGlobal)).tag(CalendarTitleMode.fixed.rawValue)
                    }
                    .pickerStyle(.segmented)

                    if CalendarTitleMode(rawValue: calendarTitleModeRaw) == .tripTitle {
                        Toggle(L10n.string(.settingsCreateEventCalendarAuto), isOn: $eventCalendarCreateIfMissing)
                        Toggle(L10n.string(.settingsCreateReminderListAuto), isOn: $reminderCalendarCreateIfMissing)
                    }

                    if isLoadingCalendarNames {
                        ProgressView(L10n.string(.settingsCalendarsLoading))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        if CalendarTitleMode(rawValue: calendarTitleModeRaw) == .fixed {
                            Picker(L10n.string(.settingsCalendarPicker), selection: eventCalendarPickerSelection) {
                                ForEach(eventCalendarPickerOptions, id: \.self) { name in
                                    Text(name == newCalendarTag ? L10n.string(.settingsCreateNewCalendar) : name).tag(name)
                                }
                            }
                            .pickerStyle(.menu)

                            if eventCalendarCreateIfMissing {
                                TextField(L10n.string(.settingsNewCalendarName), text: $calendarTitle)
                                    .textFieldStyle(.roundedBorder)
                            }

                            Divider()

                            Picker(L10n.string(.settingsReminderListPicker), selection: reminderCalendarPickerSelection) {
                                ForEach(reminderCalendarPickerOptions, id: \.self) { name in
                                    Text(name == newCalendarTag ? L10n.string(.settingsCreateNewReminderList) : name).tag(name)
                                }
                            }
                            .pickerStyle(.menu)

                            if reminderCalendarCreateIfMissing {
                                TextField(L10n.string(.settingsNewReminderList), text: $reminderCalendarTitle)
                                    .textFieldStyle(.roundedBorder)
                            }

                            if let calendarNamesError {
                                Text(calendarNamesError)
                                    .foregroundStyle(.secondary)

                                ForEach(calendarNamesPrivacyPanes, id: \.self) { pane in
                                    OpenPrivacySettingsButton(pane: pane)
                                }

                                Button(L10n.string(.actionReload)) {
                                    calendarNamesReloadToken = UUID()
                                }
                            }
                        }
                    }
                }
            } header: {
                Text(L10n.string(.settingsCalendar))
            } footer: {
                Text(L10n.string(.settingsCalendarFooter))
            }

            Section {
                Toggle(L10n.string(.settingsTripTimesToggle), isOn: $calendarTripTimesEnabled)
                    .disabled(!eventKitEnabled)
                    .help(eventKitEnabled ? L10n.string(.settingsTripTimesHelp) : L10n.string(.settingsEnableAppleCalendarFirst))

                Toggle(L10n.string(.settingsFlightTimesToggle), isOn: $calendarFlightTimesEnabled)
                    .disabled(!eventKitEnabled)
                    .help(eventKitEnabled ? L10n.string(.settingsFlightTimesHelp) : L10n.string(.settingsEnableAppleCalendarFirst))

                Toggle(L10n.string(.settingsHotelStaysToggle), isOn: $calendarHotelStaysEnabled)
                    .disabled(!eventKitEnabled)
                    .help(eventKitEnabled ? L10n.string(.settingsHotelStaysHelp) : L10n.string(.settingsEnableAppleCalendarFirst))
            } header: {
                Text(L10n.string(.settingsTravelTimes))
            } footer: {
                Text(L10n.string(.settingsTravelTimesFooter))
            }

            Section {
                TextField(L10n.string(.settingsLeadTimesDays), text: $leadTimesDaysRaw)
                    .textFieldStyle(.roundedBorder)
                    .help(L10n.string(.settingsLeadTimesHelp))

                if leadTimesDays.isEmpty {
                    Text(L10n.string(.settingsLeadTimesInvalid))
                        .foregroundStyle(.secondary)
                } else {
                    Text(L10n.format(.settingsLeadTimesDisplay, leadTimesDaysDisplayText))
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text(L10n.string(.settingsLeadTimesSection))
            } footer: {
                Text(L10n.string(.settingsLeadTimesFooter))
            }

            Section {
                Link(L10n.string(.settingsLegalPrivacy), destination: LegalURLs.privacyPolicy)
                Link(L10n.string(.settingsLegalSupport), destination: LegalURLs.support)
                Link(L10n.string(.settingsLegalImpressum), destination: LegalURLs.impressum)
            } header: {
                Text(L10n.string(.settingsLegalSection))
            } footer: {
                Text(L10n.string(.settingsLegalFooter))
            }

            Section {
                Label(L10n.string(.settingsIcloudSyncLabel), systemImage: "icloud")
                Text(cloudAccountStatusText)
                    .font(.footnote)
                    .foregroundStyle(cloudAccountStatusIsError ? .red : .secondary)
                Text(L10n.format(.settingsIcloudContainerDetail, PersistenceBootstrap.cloudKitContainerID))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } header: {
                Text(L10n.string(.settingsIcloud))
            } footer: {
                Text(cloudAccountFooterText)
            }

            Section {
                if GitHubIssueToken.isEmbedded {
                    Toggle(L10n.string(.settingsFeedbackAutoReport), isOn: $reportErrorsToGitHub)
                    TextField(L10n.string(.settingsFeedbackGitHubUsername), text: $feedbackGitHubUsername)
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.asciiCapable)
                        #endif
                }
                TextEditor(text: $feedbackText)
                    .frame(minHeight: 80)
                PublicGitHubIssueReportActions(
                    feedbackMessage: feedbackText,
                    onReported: { feedbackText = "" }
                )
                Link(L10n.string(.settingsFeedbackEmail), destination: GitHubRepository.feedbackMailtoURL)
                Link(L10n.string(.settingsFeedbackAllIssues), destination: GitHubRepository.issuesListURL)
            } header: {
                Text(L10n.string(.settingsFeedback))
            } footer: {
                Text(
                    GitHubIssueToken.isEmbedded
                        ? L10n.format(.settingsFeedbackFooterEmbedded, GitHubRepository.publicPath)
                        : L10n.format(.settingsFeedbackFooterManual, GitHubRepository.publicPath)
                )
            }

            if showsDataManagement {
                Section {
                    Button(L10n.string(.actionResetLocalStores), role: .destructive) {
                        showLocalResetConfirm = true
                    }
                    Button(L10n.string(.actionClearIcloud), role: .destructive) {
                        showCloudWipeConfirm = true
                    }
                } header: {
                    Text(L10n.string(.settingsData))
                } footer: {
                    Text(L10n.string(.settingsDataFooter))
                }
            }
        }
#if os(macOS)
        .formStyle(.grouped)
        .padding()
        .frame(width: 520, height: 620)
#endif
        .accessibilityIdentifier(UITestingIdentifiers.settings)
        .confirmationDialog(
            L10n.string(.settingsResetLocalConfirmTitle),
            isPresented: $showLocalResetConfirm,
            titleVisibility: .visible
        ) {
            Button(L10n.string(.actionDeleteLocalStores), role: .destructive) {
                onResetLocalStores?()
            }
            Button(L10n.string(.commonCancel), role: .cancel) {}
        } message: {
            Text(L10n.string(.settingsResetLocalMessage))
        }
        .confirmationDialog(
            L10n.string(.settingsClearIcloudConfirmTitle),
            isPresented: $showCloudWipeConfirm,
            titleVisibility: .visible
        ) {
            Button(L10n.string(.actionClearIcloudAndLocal), role: .destructive) {
                onWipeCloudAndReset?()
            }
            Button(L10n.string(.commonCancel), role: .cancel) {}
        } message: {
            Text(L10n.string(.settingsClearIcloudMessage))
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
            return L10n.string(.settingsIcloudStatusChecking)
        case .some(.available):
            return L10n.string(.settingsIcloudStatusAvailable)
        case .some(.noAccount):
            return L10n.string(.settingsIcloudStatusNoAccount)
        case .some(.restricted):
            return L10n.string(.settingsIcloudStatusRestricted)
        case .some(.couldNotDetermine):
            return L10n.string(.settingsIcloudStatusUnknown)
        case .some(.temporarilyUnavailable):
            return L10n.string(.settingsIcloudStatusTemporarilyUnavailable)
        case .some(let other):
            return L10n.format(.settingsIcloudStatusOther, String(describing: other))
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
            return L10n.string(.settingsIcloudFooterNoAccount)
        case .some(.restricted), .some(.temporarilyUnavailable):
            return L10n.string(.settingsIcloudFooterRestricted)
        default:
            return L10n.string(.settingsIcloudFooterDefault)
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
}
