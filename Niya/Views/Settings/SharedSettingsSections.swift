import SwiftUI
import UserNotifications

private struct FontSizeSliderRow: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text("\(Int(value))")
                .foregroundStyle(Color.niyaTeal)
                .monospacedDigit()
            Slider(value: $value, in: range, step: 1)
                .frame(width: NiyaSize.sliderWidth)
                .tint(Color.niyaTeal)
                .accessibilityLabel("\(label) font size")
                .accessibilityValue("\(Int(value))")
        }
    }
}

struct ReadingSettingsSection: View {
    @Binding var mode: ReaderMode
    @Binding var script: QuranScript
    @Binding var showTranslation: Bool
    @Binding var showTajweed: Bool
    @Binding var showSupplementalTajweedRules: Bool
    @Binding var showJuzProgress: Bool
    @Environment(QuranDataService.self) private var dataService

    var body: some View {
        Section("Reading") {
            LabeledContent("Reading Mode") {
                Picker("Reading Mode", selection: $mode) {
                    ForEach(ReaderMode.allCases, id: \.self) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
            }
            LabeledContent("Script") {
                Menu {
                    Picker("Script", selection: $script) {
                        ForEach(QuranScript.allCases) { s in
                            Text(s.displayName).tag(s)
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(script.displayName)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2)
                    }
                    .foregroundStyle(Color.niyaTeal)
                }
            }
            NavigationLink {
                TranslationPickerView()
            } label: {
                LabeledContent("Translations") {
                    Text(translationSummary)
                        .foregroundStyle(Color.niyaTeal)
                        .lineLimit(1)
                }
            }
            Toggle("Show Translation", isOn: $showTranslation)
                .tint(Color.niyaTeal)
            Toggle("Tajweed Colors", isOn: $showTajweed)
                .tint(Color.niyaTeal)
                .disabled(script != .hafs)
            Toggle("Supplemental Tajweed Rules", isOn: $showSupplementalTajweedRules)
                .tint(Color.niyaTeal)
                .disabled(script != .hafs)
            if script != .hafs {
                Text("Available for Uthmanic Hafs only")
                    .font(.caption)
                    .foregroundStyle(Color.niyaSecondary)
            }
            Toggle("Juz Progress", isOn: $showJuzProgress)
                .tint(Color.niyaTeal)
        }
    }

    private var translationSummary: String {
        let selected = dataService.selectedTranslations
        if selected.isEmpty { return "None" }
        if selected.count == 1 { return selected[0].name }
        return "\(selected[0].name) +\(selected.count - 1)"
    }
}

struct WordByWordSettingsSection: View {
    @Binding var followAlong: Bool
    @Binding var followAlongTransliteration: Bool
    @Binding var followAlongMeaning: Bool
    let script: QuranScript
    @AppStorage(StorageKey.followAlongTransliterationFontSize) private var transliterationFontSize: Double = 12
    @AppStorage(StorageKey.followAlongMeaningFontSize) private var meaningFontSize: Double = 11

    var body: some View {
        Section("Word-by-Word") {
            Toggle("Word-by-Word Mode", isOn: $followAlong)
                .tint(Color.niyaTeal)
                .disabled(script != .hafs)
            if followAlong && script == .hafs {
                Toggle("Transliteration", isOn: $followAlongTransliteration)
                    .tint(Color.niyaTeal)
                Toggle("Word Meanings", isOn: $followAlongMeaning)
                    .tint(Color.niyaTeal)
                if followAlongTransliteration {
                    FontSizeSliderRow(label: "Transliteration Size", value: $transliterationFontSize, range: 8...20)
                }
                if followAlongMeaning {
                    FontSizeSliderRow(label: "Meaning Size", value: $meaningFontSize, range: 8...20)
                }
            }
            if script != .hafs {
                Text("Available for Uthmanic Hafs only")
                    .font(.caption)
                    .foregroundStyle(Color.niyaSecondary)
            }
        }
    }
}

struct FontSizeSettingsSection: View {
    @Binding var arabicFontSize: Double
    @Binding var translationFontSize: Double

    var body: some View {
        Section("Quran Font Size") {
            FontSizeSliderRow(label: "Arabic", value: $arabicFontSize, range: 20...40)
            FontSizeSliderRow(label: "Translation", value: $translationFontSize, range: 12...24)
        }
    }
}

struct HadithFontSizeSection: View {
    @Binding var hadithArabicFontSize: Double

    var body: some View {
        Section("Hadith Font Size") {
            FontSizeSliderRow(label: "Arabic", value: $hadithArabicFontSize, range: 16...36)
        }
    }
}

struct AppearanceSettingsSection: View {
    @Binding var appearanceMode: Int

    var body: some View {
        Section("Appearance") {
            Picker("Mode", selection: $appearanceMode) {
                Text("Auto").tag(0)
                Text("Light").tag(1)
                Text("Dark").tag(2)
            }
            .pickerStyle(.segmented)
        }
    }
}

struct AudioSettingsSection<Extra: View>: View {
    @Binding var selectedReciter: Reciter
    @Binding var autoAdvance: Bool
    @Binding var loopCount: Int
    @Environment(DownloadManager.self) private var downloadManager
    private let extra: Extra

    init(selectedReciter: Binding<Reciter>, autoAdvance: Binding<Bool>, loopCount: Binding<Int>, @ViewBuilder extra: () -> Extra) {
        _selectedReciter = selectedReciter
        _autoAdvance = autoAdvance
        _loopCount = loopCount
        self.extra = extra()
    }

    var body: some View {
        Section("Audio") {
            Picker("Reciter", selection: $selectedReciter) {
                ForEach(Reciter.allCases) { r in
                    Text(r.displayName).tag(r)
                }
            }
            .pickerStyle(.navigationLink)
            .tint(Color.niyaTeal)
            Toggle("Auto-advance", isOn: $autoAdvance)
                .tint(Color.niyaTeal)
            Picker("Repeat", selection: $loopCount) {
                Text("1x").tag(1)
                Text("2x").tag(2)
                Text("3x").tag(3)
                Text("5x").tag(5)
            }
            extra
            NavigationLink {
                DownloadManagementView()
            } label: {
                LabeledContent("Manage Downloads") {
                    let totalBytes = downloadManager.totalStorageUsed()
                    if totalBytes > 0 {
                        Text(ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file))
                            .foregroundStyle(Color.niyaSecondary)
                    }
                }
            }
        }
    }
}

extension AudioSettingsSection where Extra == EmptyView {
    init(selectedReciter: Binding<Reciter>, autoAdvance: Binding<Bool>, loopCount: Binding<Int>) {
        self.init(selectedReciter: selectedReciter, autoAdvance: autoAdvance, loopCount: loopCount) { EmptyView() }
    }
}

struct PrayerTimesSettingsSection: View {
    @Binding var prayerNotifications: Bool
    @Environment(LocationService.self) private var locationService
    @Environment(PrayerTimeService.self) private var prayerTimeService
    @State private var showNotificationDeniedAlert = false

    var body: some View {
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
            .tint(Color.niyaTeal)

            Picker("Asr Juristic Method", selection: Binding(
                get: { UserDefaults.standard.integer(forKey: StorageKey.asrJuristic) == 2 ? 2 : 1 },
                set: { newValue in
                    UserDefaults.standard.set(newValue, forKey: StorageKey.asrJuristic)
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
                        .foregroundStyle(Color.niyaTeal)
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
                        PrayerNotificationScheduler.cancelAll()
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

struct DataSettingsSection: View {
    @Environment(\.stores) private var stores
    @State private var showConfirmation = false

    var body: some View {
        Section("Data") {
            Button(role: .destructive) {
                showConfirmation = true
            } label: {
                Label("Reset Home Dashboard", systemImage: "arrow.counterclockwise")
                    .foregroundStyle(.red)
            }
            .confirmationDialog(
                "Reset Home Dashboard?",
                isPresented: $showConfirmation,
                titleVisibility: .visible
            ) {
                Button("Reset", role: .destructive) {
                    stores.clearDashboard()
                }
            } message: {
                Text("This will remove all recent surahs, hadiths, and duas from the Home tab. Your bookmarks and downloads are not affected.")
            }
        }
    }
}

struct DedicationFooter: View {
    var body: some View {
        Section {
            VStack(spacing: 2) {
                Text("Dedicated to the memory of Hashim Ismail.")
                Text("May Allah (SWT) grant him Jannah.")
            }
            .font(.niyaCaption)
            .foregroundStyle(Color.niyaSecondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .listRowBackground(Color.clear)
        }
    }
}
