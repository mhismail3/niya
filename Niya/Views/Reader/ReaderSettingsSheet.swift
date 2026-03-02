import SwiftUI
import UserNotifications

struct ReaderSettingsSheet: View {
    @Bindable var vm: ReaderViewModel
    @Environment(AudioPlayerViewModel.self) private var audioPlayerVM
    @Environment(QuranDataService.self) private var dataService
    @Environment(LocationService.self) private var locationService
    @Environment(PrayerTimeService.self) private var prayerTimeService
    @AppStorage("selectedScript") private var script: QuranScript = .hafs
    @AppStorage("showTranslation") private var showTranslation: Bool = true
    @AppStorage("showTajweed") private var showTajweed: Bool = true
    @AppStorage("followAlong") private var followAlong: Bool = false
    @AppStorage("followAlongTransliteration") private var followAlongTransliteration: Bool = true
    @AppStorage("followAlongMeaning") private var followAlongMeaning: Bool = true
    @AppStorage("followAlongAutoAdvance") private var followAlongAutoAdvance: Bool = true
    @AppStorage("followAlongLoopCount") private var followAlongLoopCount: Int = 1
    @AppStorage("arabicFontSize") private var arabicFontSize: Double = 28
    @AppStorage("translationFontSize") private var translationFontSize: Double = 16
    @AppStorage("hadithArabicFontSize") private var hadithArabicFontSize: Double = 22
    @AppStorage("appearanceMode") private var appearanceMode: Int = 0
    @AppStorage("selectedReciter") private var selectedReciter: Reciter = .alAfasy
    @AppStorage("prayerNotificationsEnabled") private var prayerNotifications: Bool = false
    @State private var showNotificationDeniedAlert = false

    var body: some View {
        NavigationStack {
            List {
                Section("Reading") {
                    LabeledContent("Reading Mode") {
                        Picker("Reading Mode", selection: $vm.mode) {
                            ForEach(ReaderMode.allCases, id: \.self) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 180)
                    }
                    Picker("Script", selection: $script) {
                        ForEach(QuranScript.allCases) { s in
                            Text(s.displayName).tag(s)
                        }
                    }
                    .tint(Color.niyaTeal)
                    Toggle("Show Translation", isOn: $showTranslation)
                        .tint(Color.niyaTeal)
                    if showTranslation {
                        NavigationLink {
                            TranslationPickerView()
                        } label: {
                            LabeledContent("Translations") {
                                Text(translationSummary)
                                    .foregroundStyle(Color.niyaTeal)
                                    .lineLimit(1)
                            }
                        }
                    }
                    Toggle("Tajweed Colors", isOn: $showTajweed)
                        .tint(Color.niyaTeal)
                        .disabled(script != .hafs)
                    if script != .hafs {
                        Text("Available for Uthmanic Hafs only")
                            .font(.caption)
                            .foregroundStyle(Color.niyaSecondary)
                    }
                }

                Section("Word-by-Word") {
                    Toggle("Word-by-Word Mode", isOn: $followAlong)
                        .tint(Color.niyaTeal)
                        .disabled(script != .hafs)
                    if followAlong && script == .hafs {
                        Toggle("Transliteration", isOn: $followAlongTransliteration)
                            .tint(Color.niyaTeal)
                        Toggle("Word Meanings", isOn: $followAlongMeaning)
                            .tint(Color.niyaTeal)
                    }
                    if script != .hafs {
                        Text("Available for Uthmanic Hafs only")
                            .font(.caption)
                            .foregroundStyle(Color.niyaSecondary)
                    }
                }

                Section("Quran Font Size") {
                    HStack {
                        Text("Arabic")
                        Spacer()
                        Text("\(Int(arabicFontSize))")
                            .foregroundStyle(Color.niyaTeal)
                            .monospacedDigit()
                        Slider(value: $arabicFontSize, in: 20...40, step: 1)
                            .frame(width: 160)
                            .tint(Color.niyaTeal)
                    }
                    HStack {
                        Text("Translation")
                        Spacer()
                        Text("\(Int(translationFontSize))")
                            .foregroundStyle(Color.niyaTeal)
                            .monospacedDigit()
                        Slider(value: $translationFontSize, in: 12...24, step: 1)
                            .frame(width: 160)
                            .tint(Color.niyaTeal)
                    }
                }

                Section("Hadith Font Size") {
                    HStack {
                        Text("Arabic")
                        Spacer()
                        Text("\(Int(hadithArabicFontSize))")
                            .foregroundStyle(Color.niyaTeal)
                            .monospacedDigit()
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
                    .tint(Color.niyaTeal)
                    Toggle("Auto-advance", isOn: $followAlongAutoAdvance)
                        .tint(Color.niyaTeal)
                    Picker("Repeat", selection: $followAlongLoopCount) {
                        Text("1x").tag(1)
                        Text("2x").tag(2)
                        Text("3x").tag(3)
                        Text("5x").tag(5)
                    }
                    downloadRow
                }

                prayerTimesSection

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
    private var downloadRow: some View {
        let isDownloaded = audioPlayerVM.isDownloaded(vm.surah.id)
        let isDownloading = audioPlayerVM.downloadingSurahId == vm.surah.id

        if isDownloaded {
            Label("Audio Downloaded", systemImage: "checkmark.circle.fill")
                .foregroundStyle(Color.niyaTeal)
        } else {
            Button {
                Task { await audioPlayerVM.downloadSurah(vm.surah.id) }
            } label: {
                HStack {
                    Label("Download Audio", systemImage: "arrow.down.circle")
                    Spacer()
                    if isDownloading {
                        ProgressView(value: audioPlayerVM.downloadProgress)
                            .frame(width: 60)
                            .tint(Color.niyaGold)
                    }
                }
            }
            .disabled(isDownloading)
        }
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
