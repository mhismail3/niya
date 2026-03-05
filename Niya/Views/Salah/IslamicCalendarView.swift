import SwiftUI

struct IslamicCalendarView: View {
    @Environment(LocationService.self) private var locationService
    @AppStorage(StorageKey.calculationMethod) private var storedMethod: String = CalculationMethod.isna.rawValue
    @AppStorage(StorageKey.asrJuristic) private var asrJuristic: Int = 1
    @State private var currentMonth = HijriMonth.current()
    @State private var selectedDay: Int?
    @State private var selectedDayTimes: DailyPrayerTimes?
    @State private var prayerTimesCache: [DateComponents: DailyPrayerTimes] = [:]

    private let hijriCal = Calendar(identifier: .islamicUmmAlQura)
    private let weekdays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    private var calculationMethod: CalculationMethod {
        CalculationMethod(rawValue: storedMethod) ?? .isna
    }

    private var todayHijriDay: Int? {
        let today = HijriMonth.current()
        guard today == currentMonth else { return nil }
        return hijriCal.component(.day, from: Date())
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    monthHeader
                    weekdayHeader
                    dayGrid
                    if let day = selectedDay {
                        prayerDetailCard(for: day)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                .padding()
            }
            .navigationTitle("Islamic Calendar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Today") {
                        withAnimation {
                            currentMonth = HijriMonth.current()
                            selectedDay = hijriCal.component(.day, from: Date())
                            computePrayerTimes(forDay: selectedDay!)
                        }
                    }
                    .font(.niyaCaption)
                }
            }
        }
        .onChange(of: currentMonth) { _, _ in
            withAnimation {
                selectedDay = nil
                selectedDayTimes = nil
            }
        }
    }

    // MARK: - Month Header

    private var monthHeader: some View {
        VStack(spacing: 4) {
            HStack {
                Button { withAnimation { currentMonth = currentMonth.previous } } label: {
                    Image(systemName: "chevron.left")
                        .fontWeight(.medium)
                }

                Spacer()

                VStack(spacing: 2) {
                    Text("\(currentMonth.displayName) \(String(currentMonth.year)) AH")
                        .font(.niyaHeadline)
                        .foregroundStyle(Color.niyaText)

                    let range = currentMonth.gregorianDateRange
                    Text(gregorianRangeString(start: range.start, end: range.end))
                        .font(.caption2)
                        .foregroundStyle(Color.niyaSecondary)
                }

                Spacer()

                Button { withAnimation { currentMonth = currentMonth.next } } label: {
                    Image(systemName: "chevron.right")
                        .fontWeight(.medium)
                }
            }
            .foregroundStyle(Color.niyaTeal)
        }
        .padding(.bottom, 4)
    }

    // MARK: - Weekday Header

    private var weekdayHeader: some View {
        LazyVGrid(columns: columns, spacing: 0) {
            ForEach(weekdays, id: \.self) { day in
                Text(day)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.niyaSecondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Day Grid

    private var dayGrid: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            let leadingBlanks = currentMonth.firstWeekday - 1
            ForEach(0..<leadingBlanks, id: \.self) { _ in
                Color.clear.frame(height: 44)
            }

            ForEach(1...currentMonth.dayCount, id: \.self) { day in
                dayCell(day)
            }
        }
    }

    private func dayCell(_ day: Int) -> some View {
        let isToday = todayHijriDay == day
        let isSelected = selectedDay == day
        let gregDate = currentMonth.gregorianDate(forDay: day)
        let gregDay = Calendar(identifier: .gregorian).component(.day, from: gregDate)

        return Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                selectedDay = day
                computePrayerTimes(forDay: day)
            }
        } label: {
            VStack(spacing: 2) {
                Text("\(day)")
                    .font(.system(.body, design: .rounded))
                    .fontWeight(isToday || isSelected ? .bold : .regular)
                    .foregroundStyle(
                        isSelected ? .white :
                        isToday ? Color.niyaTeal :
                        Color.niyaText
                    )

                Text("\(gregDay)")
                    .font(.system(size: 9))
                    .foregroundStyle(
                        isSelected ? .white.opacity(0.8) :
                        Color.niyaSecondary
                    )
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background {
                if isSelected {
                    Circle()
                        .fill(Color.niyaGold)
                } else if isToday {
                    Circle()
                        .strokeBorder(Color.niyaTeal, lineWidth: 1.5)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Prayer Detail Card

    private func prayerDetailCard(for day: Int) -> some View {
        let gregDate = currentMonth.gregorianDate(forDay: day)

        return VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(day) \(currentMonth.displayName) \(String(currentMonth.year)) AH")
                        .font(.niyaCaption)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.niyaText)
                    Text(gregorianDateString(gregDate))
                        .font(.caption2)
                        .foregroundStyle(Color.niyaSecondary)
                }
                Spacer()
                if let name = locationService.effectiveLocation?.name, !name.isEmpty {
                    Text(name)
                        .font(.caption2)
                        .foregroundStyle(Color.niyaSecondary)
                }
            }

            if let times = selectedDayTimes {
                let tz = locationService.effectiveLocation?.timeZone ?? .current
                ForEach(times.times, id: \.prayer) { pt in
                    HStack {
                        Image(systemName: pt.prayer.icon)
                            .foregroundStyle(Color.niyaTeal)
                            .frame(width: 24)
                        Text(pt.prayer.displayName)
                            .font(.niyaBody)
                        Spacer()
                        Text(formattedTime(pt.time, timeZone: tz))
                            .font(.niyaBody)
                            .monospacedDigit()
                    }
                    .foregroundStyle(Color.niyaText)
                    .padding(.vertical, 2)
                }
            } else {
                Text("Set your location to see prayer times")
                    .font(.niyaCaption)
                    .foregroundStyle(Color.niyaSecondary)
                    .padding(.vertical, 8)
            }
        }
        .padding()
        .niyaCard()
    }

    // MARK: - Prayer Time Computation

    private func computePrayerTimes(forDay day: Int) {
        guard let location = locationService.effectiveLocation else {
            selectedDayTimes = nil
            return
        }
        let gregDate = currentMonth.gregorianDate(forDay: day)
        let gregCal = Calendar(identifier: .gregorian)
        let key = gregCal.dateComponents([.year, .month, .day], from: gregDate)

        if let cached = prayerTimesCache[key] {
            selectedDayTimes = cached
            return
        }

        let times = PrayerTimeCalculator.calculate(
            date: gregDate,
            location: location,
            method: calculationMethod,
            asrFactor: asrJuristic
        )
        prayerTimesCache[key] = times
        selectedDayTimes = times
    }

    // MARK: - Formatting

    private func gregorianRangeString(start: Date, end: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let startStr = formatter.string(from: start)
        formatter.dateFormat = "MMM d, yyyy"
        let endStr = formatter.string(from: end)
        return "\(startStr) – \(endStr)"
    }

    private func gregorianDateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    private func formattedTime(_ date: Date, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        formatter.timeZone = timeZone
        return formatter.string(from: date)
    }
}
