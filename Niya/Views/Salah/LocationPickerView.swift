import SwiftUI
import MapKit

struct LocationPickerView: View {
    @Environment(LocationService.self) private var locationService
    @Environment(PrayerTimeService.self) private var prayerTimeService
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var isSelecting = false

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

                if locationService.isSearching {
                    Section {
                        HStack {
                            ProgressView()
                            Text("Searching...")
                                .font(.niyaCaption)
                                .foregroundStyle(Color.niyaSecondary)
                        }
                    }
                } else if !locationService.searchCompletions.isEmpty {
                    Section("Results") {
                        ForEach(locationService.searchCompletions, id: \.self) { completion in
                            Button {
                                selectCompletion(completion)
                            } label: {
                                HStack {
                                    Image(systemName: "mappin")
                                        .foregroundStyle(Color.niyaSecondary)
                                    VStack(alignment: .leading) {
                                        Text(completion.title)
                                            .foregroundStyle(Color.niyaText)
                                        if !completion.subtitle.isEmpty {
                                            Text(completion.subtitle)
                                                .font(.niyaCaption)
                                                .foregroundStyle(Color.niyaSecondary)
                                        }
                                    }
                                    Spacer()
                                    if isSelecting {
                                        ProgressView()
                                    }
                                }
                            }
                            .disabled(isSelecting)
                        }
                    }
                } else if !searchText.isEmpty && !locationService.isSearching {
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
                locationService.updateSearchQuery(newValue)
            }
            .onDisappear {
                locationService.stopSearch()
            }
        }
    }

    private func selectCompletion(_ completion: MKLocalSearchCompletion) {
        isSelecting = true
        Task {
            if let loc = await locationService.selectCompletion(completion) {
                locationService.manualLocation = loc
                prayerTimeService.recalculate(location: loc)
                dismiss()
            }
            isSelecting = false
        }
    }
}
