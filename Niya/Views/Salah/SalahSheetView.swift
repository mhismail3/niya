import SwiftUI
import UserNotifications

struct SalahSheetView: View {
    @Environment(LocationService.self) private var locationService
    @Environment(PrayerTimeService.self) private var prayerTimeService
    @AppStorage(StorageKey.prayerNotificationsEnabled) private var prayerNotifications = false
    @State private var showLocationPicker = false
    @State private var showCalendar = false
    @State private var showNotificationDeniedAlert = false
    private let compactCompassSize: CGFloat = 168

    private var location: UserLocation? {
        locationService.effectiveLocation
    }

    private var bearing: Double {
        guard let loc = location else { return 0 }
        return PrayerTimeCalculator.qiblahBearing(from: loc)
    }

    var body: some View {
        NavigationStack {
            sheetContent
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .navigationTitle("Prayer Times")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            showCalendar = true
                        } label: {
                            toolbarLabel("Calendar", systemName: "calendar")
                        }
                        .accessibilityLabel("Calendar")
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showLocationPicker = true
                        } label: {
                            toolbarLabel("Set Location", systemName: "location.circle")
                        }
                        .accessibilityLabel("Set Location")
                    }
                }
                .sheet(isPresented: $showCalendar) {
                    IslamicCalendarView()
                }
                .sheet(isPresented: $showLocationPicker) {
                    LocationPickerView()
                        .presentationDetents([.medium, .large])
                        .presentationDragIndicator(.hidden)
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
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
    }

    private func toolbarLabel(_ title: String, systemName: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: systemName)
            Text(title)
                .font(.niyaControlLabel)
        }
            .foregroundStyle(Color.niyaTeal)
    }

    @ViewBuilder
    private var sheetContent: some View {
        if let loc = location, let times = prayerTimeService.activeTimes {
            loadedContent(location: loc, times: times)
        } else if locationService.authorizationStatus == .denied ||
                  locationService.authorizationStatus == .restricted {
            locationDeniedView
        } else {
            loadingView
        }
    }

    private func loadedContent(location loc: UserLocation, times: DailyPrayerTimes) -> some View {
        VStack(spacing: 12) {
            HStack(alignment: .top, spacing: 16) {
                qiblahPanel

                nextPrayerSummary(location: loc)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }

            SalahPrayerCardGrid(times: times, timeZone: loc.timeZone)

            notificationToggle(location: loc)
        }
        .padding(.horizontal, 18)
        .padding(.top, 6)
        .padding(.bottom, 12)
    }

    private var qiblahPanel: some View {
        QiblahCompassView(
            bearing: bearing,
            heading: locationService.heading,
            headingAvailable: locationService.isHeadingAvailable,
            headingAccuracy: locationService.headingAccuracy,
            compassSize: compactCompassSize,
            showsAccuracyBanner: false,
            showsBearingText: false
        )
        .frame(width: compactCompassSize, height: compactCompassSize, alignment: .topLeading)
    }

    private func nextPrayerSummary(location loc: UserLocation) -> some View {
        VStack(alignment: .trailing, spacing: 7) {
            Text("Next Prayer")
                .font(.niyaHeadline)
                .foregroundStyle(Color.niyaText)

            if let next = prayerTimeService.activeTimes?.nextPrayer(after: Date()),
               !prayerTimeService.formattedCountdown.isEmpty {
                Text("\(next.prayer.displayName(on: Date())) in \(prayerTimeService.formattedCountdown)")
                    .font(.niyaEmphasis)
                    .foregroundStyle(Color.niyaTeal)
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)
                    .multilineTextAlignment(.trailing)
            } else {
                Text("All prayers complete")
                    .font(.niyaEmphasis)
                    .foregroundStyle(Color.niyaTeal)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .multilineTextAlignment(.trailing)
            }

            VStack(alignment: .trailing, spacing: 3) {
                Text(HijriFormatter.format(date: Date()))
                Text(loc.name)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
                    .multilineTextAlignment(.trailing)
            }
            .font(.niyaSubheadline)
            .foregroundStyle(Color.niyaSecondary)
            .padding(.top, 2)

            if let accuracy = compassAccuracyMessage {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Image(systemName: accuracy.icon)
                    Text(accuracy.text)
                }
                .font(.niyaCaption)
                .foregroundStyle(accuracy.color)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .multilineTextAlignment(.trailing)
                .padding(.top, 4)
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "building.columns")
                    Text("\(Int(bearing))° \(cardinalDirection(for: bearing))")
                }
                .font(.niyaCaption)
                .foregroundStyle(Color.niyaTeal)
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private var compassAccuracyMessage: (icon: String, text: String, color: Color)? {
        guard locationService.isHeadingAvailable else {
            return ("location.slash", "Compass is unavailable", .niyaSecondary)
        }
        if locationService.headingAccuracy < 0 {
            return ("figure.wave", "Move device to calibrate", .niyaGold)
        }
        if locationService.headingAccuracy > 25 {
            return ("figure.wave", "Low compass accuracy", .red)
        }
        if locationService.headingAccuracy > 15 {
            return ("exclamationmark.triangle", "Compass accuracy is reduced", .niyaGold)
        }
        return nil
    }

    private func cardinalDirection(for degrees: Double) -> String {
        let directions = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE",
                          "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"]
        let index = Int((degrees + 11.25) / 22.5) % 16
        return directions[index]
    }

    private func notificationToggle(location loc: UserLocation) -> some View {
        Toggle(isOn: $prayerNotifications) {
            Text("Prayer Notifications")
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
            .font(.niyaHeadline)
            .tint(Color.niyaTeal)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .center)
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
                            prayerTimeService.recalculate(location: loc)
                        } else {
                            prayerTimeService.recalculate(location: loc)
                        }
                    }
                } else {
                    PrayerNotificationScheduler.cancelAll()
                }
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

private struct SalahPrayerCardGrid: View {
    let times: DailyPrayerTimes
    let timeZone: TimeZone

    private var now: Date { Date() }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 7) {
            ForEach(times.times, id: \.prayer) { prayerTime in
                prayerCard(prayerTime)
            }
        }
    }

    private func prayerCard(_ prayerTime: PrayerTime) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center, spacing: 4) {
                Image(systemName: prayerTime.prayer.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(rowColor(prayerTime))

                Spacer(minLength: 4)

                statusIndicator(for: prayerTime)
            }

            Text(prayerTime.prayer.displayName(on: times.date))
                .font(.niyaCardTitle)
                .foregroundStyle(rowColor(prayerTime))
                .lineLimit(1)
                .minimumScaleFactor(0.68)
                .allowsTightening(true)

            Text(formattedTime(prayerTime.time))
                .font(.niyaCardValue)
                .foregroundStyle(rowColor(prayerTime))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .allowsTightening(true)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, minHeight: 68, alignment: .topLeading)
        .background(cardBackground(for: prayerTime))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(cardBorder(for: prayerTime), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(prayerTime.prayer.displayName(on: times.date)), \(formattedTime(prayerTime.time))")
    }

    @ViewBuilder
    private func statusIndicator(for prayerTime: PrayerTime) -> some View {
        if isCurrent(prayerTime) {
            Text("Now")
                .font(.niyaBadge)
                .foregroundStyle(Color.niyaGold)
        } else if isNext(prayerTime) {
            Text("Next")
                .font(.niyaBadge)
                .foregroundStyle(Color.niyaTeal)
        } else if hasPassed(prayerTime) && prayerTime.prayer.isActualPrayer {
            Image(systemName: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(Color.niyaSecondary)
        }
    }

    private func currentPrayer() -> PrayerName? {
        let actual = times.times.filter { $0.prayer.isActualPrayer }
        for (index, prayerTime) in actual.enumerated() {
            let nextTime = index + 1 < actual.count ? actual[index + 1].time : nil
            if prayerTime.time <= now && (nextTime == nil || now < nextTime!) {
                return prayerTime.prayer
            }
        }
        return nil
    }

    private func isCurrent(_ prayerTime: PrayerTime) -> Bool {
        prayerTime.prayer == currentPrayer()
    }

    private func isNext(_ prayerTime: PrayerTime) -> Bool {
        times.nextPrayer(after: now)?.prayer == prayerTime.prayer
    }

    private func hasPassed(_ prayerTime: PrayerTime) -> Bool {
        prayerTime.time <= now && !isCurrent(prayerTime)
    }

    private func rowColor(_ prayerTime: PrayerTime) -> Color {
        if isCurrent(prayerTime) { return Color.niyaGold }
        if isNext(prayerTime) { return Color.niyaTeal }
        if hasPassed(prayerTime) { return Color.niyaSecondary }
        return Color.niyaText
    }

    private func cardBackground(for prayerTime: PrayerTime) -> Color {
        if isCurrent(prayerTime) { return Color.niyaGold.opacity(0.14) }
        if isNext(prayerTime) { return Color.niyaTeal.opacity(0.12) }
        if hasPassed(prayerTime) { return Color.niyaSurface.opacity(0.72) }
        return Color.niyaSurface
    }

    private func cardBorder(for prayerTime: PrayerTime) -> Color {
        if isCurrent(prayerTime) { return Color.niyaGold.opacity(0.42) }
        if isNext(prayerTime) { return Color.niyaTeal.opacity(0.36) }
        return Color.niyaSecondary.opacity(0.18)
    }

    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        formatter.timeZone = timeZone
        return formatter.string(from: date)
    }
}
