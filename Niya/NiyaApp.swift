import SwiftUI
import SwiftData

@main
struct NiyaApp: App {
    @State private var dataService = QuranDataService()
    @State private var audioService = AudioService()
    @State private var audioPlayerVM: AudioPlayerViewModel

    private let container: ModelContainer

    init() {
        let ds = QuranDataService()
        let as_ = AudioService()
        let avm = AudioPlayerViewModel(audioService: as_, dataService: ds)
        _dataService = State(wrappedValue: ds)
        _audioService = State(wrappedValue: as_)
        _audioPlayerVM = State(wrappedValue: avm)

        do {
            container = try ModelContainer(for: AudioDownload.self, ReadingPosition.self, RecentSearch.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }

        as_.configureSession()
    }

    @AppStorage("appearanceMode") private var appearanceMode: Int = 0

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(dataService)
                .environment(audioService)
                .environment(audioPlayerVM)
                .modelContainer(container)
                .preferredColorScheme(appearanceMode == 0 ? nil : appearanceMode == 1 ? .light : .dark)
        }
    }
}
