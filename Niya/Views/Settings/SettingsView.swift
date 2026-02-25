import SwiftUI

struct SettingsView: View {
    @AppStorage("selectedScript") private var script: QuranScript = .hafs
    @AppStorage("showTranslation") private var showTranslation: Bool = true
    @Environment(AudioPlayerViewModel.self) private var audioPlayerVM

    var body: some View {
        NavigationStack {
            List {
                Section("Reading") {
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

                Section("About") {
                    LabeledContent("Quran Text", value: "quran-json (MIT)")
                    LabeledContent("Simple Arabic", value: "alquran.cloud (CC-BY)")
                    LabeledContent("Font", value: "Scheherazade New (OFL)")
                    Link("Report an Issue", destination: URL(string: "https://github.com")!)
                        .foregroundStyle(Color.niyaTeal)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
        }
    }
}
