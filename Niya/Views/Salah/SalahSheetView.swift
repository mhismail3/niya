import SwiftUI

struct SalahSheetView: View {
    @Environment(LocationService.self) private var locationService
    @Environment(PrayerTimeService.self) private var prayerTimeService
    @State private var showLocationPicker = false
    @State private var showCalendar = false
    @State private var selectedDetent: PresentationDetent = .medium

    private var location: UserLocation? {
        locationService.effectiveLocation
    }

    private var bearing: Double {
        guard let loc = location else { return 0 }
        return PrayerTimeCalculator.qiblahBearing(from: loc)
    }

    private var compassSize: CGFloat {
        selectedDetent == .large ? 260 : 160
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if let loc = location, let times = prayerTimeService.activeTimes {
                        QiblahCompassView(
                            bearing: bearing,
                            heading: locationService.heading,
                            headingAvailable: locationService.isHeadingAvailable,
                            headingAccuracy: locationService.headingAccuracy,
                            compassSize: compassSize
                        )
                        .animation(.smooth, value: compassSize)

                        if !prayerTimeService.formattedCountdown.isEmpty {
                            countdownView
                        }

                        PrayerTimesListView(
                            times: times,
                            timeZone: loc.timeZone,
                            locationName: loc.name,
                            showAll: selectedDetent == .large,
                            compact: selectedDetent == .medium
                        )
                        .padding(.horizontal)
                    } else if locationService.authorizationStatus == .denied ||
                              locationService.authorizationStatus == .restricted {
                        locationDeniedView
                    } else {
                        loadingView
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Salah")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showCalendar = true
                    } label: {
                        Image(systemName: "calendar")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showLocationPicker = true
                    } label: {
                        Image(systemName: "location.circle")
                    }
                }
            }
            .sheet(isPresented: $showCalendar) {
                IslamicCalendarView()
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showLocationPicker) {
                LocationPickerView()
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.hidden)
            }
        }
        .onAppear {
            locationService.startHeading()
            locationService.startLocationUpdates()
            if let loc = location {
                prayerTimeService.recalculate(location: loc)
            }
        }
        .onDisappear {
            locationService.stopHeading()
        }
        .onChange(of: locationService.effectiveLocation) { _, newLoc in
            if let loc = newLoc {
                prayerTimeService.recalculate(location: loc)
            }
        }
        .presentationDetents([.medium, .large], selection: $selectedDetent)
        .presentationDragIndicator(.hidden)
    }

    private var countdownView: some View {
        VStack(spacing: 4) {
            if let next = prayerTimeService.activeTimes?.nextPrayer(after: Date()) {
                Text("Next: \(next.prayer.displayName)")
                    .font(.niyaCaption)
                    .foregroundStyle(Color.niyaSecondary)
            }
            Text(prayerTimeService.formattedCountdown)
                .font(.system(.title2, design: .monospaced))
                .fontWeight(.medium)
                .foregroundStyle(Color.niyaTeal)
        }
    }

    private var locationDeniedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "location.slash")
                .font(.system(size: 40))
                .foregroundStyle(Color.niyaSecondary)

            Text("Location Access Needed")
                .font(.niyaHeadline)

            Text("Allow location access for automatic prayer times and Qiblah direction, or set your location manually.")
                .font(.niyaCaption)
                .foregroundStyle(Color.niyaSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            HStack(spacing: 12) {
                Button("Set Manually") {
                    showLocationPicker = true
                }
                .buttonStyle(.bordered)

                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    Link("Open Settings", destination: settingsURL)
                        .buttonStyle(.borderedProminent)
                        .tint(Color.niyaTeal)
                }
            }
        }
        .padding()
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Acquiring location...")
                .font(.niyaCaption)
                .foregroundStyle(Color.niyaSecondary)

            Button("Set Location Manually") {
                showLocationPicker = true
            }
            .font(.niyaCaption)
            .padding(.top, 8)
        }
        .padding()
    }
}
