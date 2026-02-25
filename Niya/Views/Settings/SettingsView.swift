import SwiftUI

struct SettingsView: View {
    @AppStorage("selectedScript") private var script: QuranScript = .hafs
    @AppStorage("showTranslation") private var showTranslation: Bool = true
    @AppStorage("readerMode") private var mode: ReaderMode = .scroll
    @Environment(AudioPlayerViewModel.self) private var audioPlayerVM

    var body: some View {
        NavigationStack {
            List {
                Section("Reading") {
                    Picker("Mode", selection: $mode) {
                        ForEach(ReaderMode.allCases, id: \.self) { m in
                            Text(m.rawValue).tag(m)
                        }
                    }
                    .pickerStyle(.segmented)
                    Picker("Script", selection: $script) {
                        ForEach(QuranScript.allCases) { s in
                            Text(s.displayName).tag(s)
                        }
                    }
                    Toggle("Show Translation", isOn: $showTranslation)
                        .tint(Color.niyaTeal)
                }

                Section("Audio") {
                    LabeledContent("Reciter", value: "Mishary Rashid Al-Afasy")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
        }
    }
}
