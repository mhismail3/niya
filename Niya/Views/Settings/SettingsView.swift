import SwiftUI

struct SettingsView: View {
    @AppStorage("selectedScript") private var script: QuranScript = .hafs
    @AppStorage("showTranslation") private var showTranslation: Bool = true
    @AppStorage("readerMode") private var mode: ReaderMode = .scroll
    @AppStorage("arabicFontSize") private var arabicFontSize: Double = 28
    @AppStorage("translationFontSize") private var translationFontSize: Double = 16
    @AppStorage("hadithArabicFontSize") private var hadithArabicFontSize: Double = 22
    @AppStorage("appearanceMode") private var appearanceMode: Int = 0
    @AppStorage("selectedReciter") private var selectedReciter: Reciter = .alAfasy
    @Environment(AudioPlayerViewModel.self) private var audioPlayerVM

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
            .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
        }
    }
}
