import SwiftUI

struct LocationPickerView: View {
    @Environment(LocationService.self) private var locationService
    @Environment(PrayerTimeService.self) private var prayerTimeService
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var searchResults: [UserLocation] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        locationService.manualLocation = nil
                        locationService.startLocationUpdates()
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: "location.fill")
                                .foregroundStyle(Color.niyaTeal)
                            Text("Use Current Location")
                                .foregroundStyle(Color.niyaText)
                            Spacer()
                            if locationService.manualLocation == nil {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.niyaTeal)
                            }
                        }
                    }
                }

                if let manual = locationService.manualLocation {
                    Section("Current Location") {
                        HStack {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundStyle(Color.niyaTeal)
                            Text(manual.name)
                                .foregroundStyle(Color.niyaText)
                        }
                    }
                }

                Section("Search City") {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(Color.niyaSecondary)
                        TextField("Enter city name", text: $searchText)
                            .textFieldStyle(.plain)
                            .autocorrectionDisabled()
                    }
                }

                if isSearching {
                    Section {
                        HStack {
                            ProgressView()
                            Text("Searching...")
                                .font(.niyaCaption)
                                .foregroundStyle(Color.niyaSecondary)
                        }
                    }
                } else if !searchResults.isEmpty {
                    Section("Results") {
                        ForEach(searchResults, id: \.name) { loc in
                            Button {
                                locationService.manualLocation = loc
                                prayerTimeService.recalculate(location: loc)
                                dismiss()
                            } label: {
                                HStack {
                                    Image(systemName: "mappin")
                                        .foregroundStyle(Color.niyaSecondary)
                                    VStack(alignment: .leading) {
                                        Text(loc.name)
                                            .foregroundStyle(Color.niyaText)
                                        Text(String(format: "%.2f, %.2f", loc.latitude, loc.longitude))
                                            .font(.niyaCaption)
                                            .foregroundStyle(Color.niyaSecondary)
                                    }
                                }
                            }
                        }
                    }
                } else if !searchText.isEmpty && !isSearching {
                    Section {
                        Text("No results found")
                            .font(.niyaCaption)
                            .foregroundStyle(Color.niyaSecondary)
                    }
                }
            }
            .navigationTitle("Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onChange(of: searchText) { _, newValue in
                searchTask?.cancel()
                guard !newValue.isEmpty else {
                    searchResults = []
                    return
                }
                searchTask = Task {
                    try? await Task.sleep(for: .milliseconds(500))
                    guard !Task.isCancelled else { return }
                    isSearching = true
                    let results = await locationService.geocodeCity(newValue)
                    guard !Task.isCancelled else { return }
                    searchResults = results
                    isSearching = false
                }
            }
        }
    }
}
