import SwiftUI
import UserNotifications

struct SettingsView: View {
    @AppStorage("selectedScript") private var script: QuranScript = .hafs
    @AppStorage("showTranslation") private var showTranslation: Bool = true
    @AppStorage("readerMode") private var mode: ReaderMode = .scroll
    @AppStorage("arabicFontSize") private var arabicFontSize: Double = 28
    @AppStorage("translationFontSize") private var translationFontSize: Double = 16
    @AppStorage("hadithArabicFontSize") private var hadithArabicFontSize: Double = 22
    @AppStorage("appearanceMode") private var appearanceMode: Int = 0
    @AppStorage("selectedReciter") private var selectedReciter: Reciter = .alAfasy
    @AppStorage("prayerNotificationsEnabled") private var prayerNotifications: Bool = false
    @State private var showNotificationDeniedAlert = false
    @Environment(AudioPlayerViewModel.self) private var audioPlayerVM
    @Environment(QuranDataService.self) private var dataService
    @Environment(LocationService.self) private var locationService
    @Environment(PrayerTimeService.self) private var prayerTimeService

    var body: some View {
        NavigationStack {
            List {
                Section("Reading") {
                    LabeledContent("Reading Mode") {
                        Picker("Reading Mode", selection: $mode) {
                            ForEach(ReaderMode.allCases, id: \.self) { m in
                                Text(m.rawValue).tag(m)
                            }
                        }
                        .pickerStyle(.segmented)
                        .fixedSize()
                    }
                    Picker("Script", selection: $script) {
                        ForEach(QuranScript.allCases) { s in
                            Text(s.displayName).tag(s)
                        }
                    }
                    Toggle("Show Translation", isOn: $showTranslation)
                        .tint(Color.niyaTeal)
                    if showTranslation {
                        NavigationLink {
                            TranslationPickerView()
                        } label: {
                            LabeledContent("Translations") {
                                Text(translationSummary)
                                    .foregroundStyle(Color.niyaSecondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                }

                Section("Quran Font Size") {
                    LabeledContent("Arabic — \(Int(arabicFontSize))") {
                        Slider(value: $arabicFontSize, in: 20...40, step: 1)
                            .frame(width: 160)
                            .tint(Color.niyaTeal)
                    }
                    LabeledContent("Translation — \(Int(translationFontSize))") {
                        Slider(value: $translationFontSize, in: 12...24, step: 1)
                            .frame(width: 160)
                            .tint(Color.niyaTeal)
                    }
                }

                Section("Hadith Font Size") {
                    LabeledContent("Arabic — \(Int(hadithArabicFontSize))") {
                        Slider(value: $hadithArabicFontSize, in: 16...36, step: 1)
                            .frame(width: 160)
                            .tint(Color.niyaTeal)
                    }
                }

                Section("Appearance") {
                    Picker("Mode", selection: $appearanceMode) {
                        Text("Auto").tag(0)
                        Text("Light").tag(1)
                        Text("Dark").tag(2)
                    }
                    .pickerStyle(.segmented)
                }

                Section("Audio") {
                    Picker("Reciter", selection: $selectedReciter) {
                        ForEach(Reciter.allCases) { r in
                            Text(r.displayName).tag(r)
                        }
                    }
                }

                prayerTimesSection

                Section {
                    Text("Dedicated to the memory of Hashim Ismail - may Allah (SWT) grant him Jannah")
                        .font(.niyaCaption)
                        .foregroundStyle(Color.niyaSecondary)
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .hiddenNavBarBackground()
        }
    }

    private var translationSummary: String {
        let selected = dataService.selectedTranslations
        if selected.isEmpty { return "None" }
        if selected.count == 1 { return selected[0].name }
        return "\(selected[0].name) +\(selected.count - 1)"
    }

    @ViewBuilder
    private var prayerTimesSection: some View {
        Section("Prayer Times") {
            Picker("Calculation Method", selection: Binding(
                get: { prayerTimeService.calculationMethod },
                set: { newMethod in
                    prayerTimeService.calculationMethod = newMethod
                    if let loc = locationService.effectiveLocation {
                        prayerTimeService.recalculate(location: loc)
                    }
                }
            )) {
                ForEach(CalculationMethod.allCases) { m in
                    Text(m.displayName).tag(m)
                }
            }
            .pickerStyle(.navigationLink)

            Picker("Asr Juristic Method", selection: Binding(
                get: { UserDefaults.standard.integer(forKey: "asrJuristic") == 2 ? 2 : 1 },
                set: { newValue in
                    UserDefaults.standard.set(newValue, forKey: "asrJuristic")
                    if let loc = locationService.effectiveLocation {
                        prayerTimeService.recalculate(location: loc)
                    }
                }
            )) {
                Text("Shafi'i / Standard").tag(1)
                Text("Hanafi").tag(2)
            }

            NavigationLink {
                LocationPickerView()
            } label: {
                LabeledContent("Location") {
                    Text(locationService.effectiveLocation?.name ?? "Not Set")
                        .foregroundStyle(Color.niyaSecondary)
                }
            }

            Toggle("Prayer Notifications", isOn: $prayerNotifications)
                .tint(Color.niyaTeal)
                .onChange(of: prayerNotifications) { _, enabled in
                    if enabled {
                        Task {
                            let center = UNUserNotificationCenter.current()
                            let settings = await center.notificationSettings()
                            if settings.authorizationStatus == .denied {
                                prayerNotifications = false
                                showNotificationDeniedAlert = true
                            } else if settings.authorizationStatus == .notDetermined {
                                let granted = try? await center.requestAuthorization(options: [.alert, .sound])
                                if granted != true {
                                    prayerNotifications = false
                                    return
                                }
                                if let loc = locationService.effectiveLocation {
                                    prayerTimeService.recalculate(location: loc)
                                }
                            } else {
                                if let loc = locationService.effectiveLocation {
                                    prayerTimeService.recalculate(location: loc)
                                }
                            }
                        }
                    } else {
                        prayerTimeService.cancelNotifications()
                    }
                }
                .alert("Notifications Disabled", isPresented: $showNotificationDeniedAlert) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        Link("Open Settings", destination: url)
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Enable notifications in Settings to receive prayer time alerts.")
                }
        }
    }
}
