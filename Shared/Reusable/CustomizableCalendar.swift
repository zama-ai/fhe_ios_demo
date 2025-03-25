// Copyright © 2025 Zama. All rights reserved.

import SwiftUI

#Preview {
    @Previewable @State var selection: Date?
    @Previewable @State var calendar = Calendar.current
    @Previewable @State var locale = Locale.current
    
    let currentYear: DateInterval = calendar.dateInterval(of: .year, for: Date().addingTimeInterval(-3600 * 24 * 300))!
    let samples: [Date] = calendar.generateDates(in: currentYear, matching: DateComponents(day: 5))
    
    VStack {
        Picker("Locale", selection: $locale) {
            Text("FR").tag(Locale(identifier: "fr_FR"))
            Text("US").tag(Locale(identifier: "en_US"))
        }
        .pickerStyle(.segmented)
        .onChange(of: locale) {
            calendar.locale = locale
        }
        
        DatePicker("Selection:",
                   selection: .init(get: { selection ?? Date.now }, set: { selection = $0 }),
                   in: currentYear.start...currentYear.end,
                   displayedComponents: .date)
        
        CalendarView(covering: currentYear,
                     selection: $selection,
                     canSelect: { samples.contains($0) }) { date in
            Text(String(calendar.component(.day, from: date)))
                .font(.caption)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.yellow.opacity(selection == date ? 1 : 0))
                .overlay(alignment: .bottom) {
                    if samples.contains(date) {
                        Circle()
                            .frame(width: 3)
                            .padding(.bottom, 3)
                    }
                }
        } monthHeader: { month in
            let component = calendar.component(.month, from: month)
            // Append year for any January, any December, and the month the calendar starts at
            let showYear = component == 1 || calendar.isDate(month, equalTo: currentYear.start, toGranularity: .month)
            Text(month.formatted(.dateTime.month(.wide).year(showYear ? .defaultDigits : .omitted).locale(locale)).capitalized)
                .font(.title)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 16)
                .padding(.bottom, 12)
        } weekdayHeader: { column in
            Text(column.prefix(3))
                .textCase(.uppercase)
                .font(.caption2)
                .bold()
        }
        .background(Color.yellow.opacity(0.1))
        .buttonStyle(.borderedProminent)
        .environment(\.calendar, calendar)
        .environment(\.locale, locale)
    }
    .padding()
}

struct CalendarView<DayCell, MonthHeader, WeekdayHeader>: View where DayCell: View, MonthHeader: View, WeekdayHeader: View {
    @Environment(\.calendar) private var calendar
    @Binding private var selection: Date?
    private let canSelect: (Date) -> Bool
    
    private let interval: DateInterval
    private let dayCell: (Date) -> DayCell
    private let monthHeader: (Date) -> MonthHeader
    private let weekdayHeader: (String) -> WeekdayHeader
    
    init(covering interval: DateInterval,
         selection: Binding<Date?>,
         canSelect: @escaping (Date) -> Bool = { _ in true },
         @ViewBuilder dayCell: @escaping (Date) -> DayCell,
         @ViewBuilder monthHeader: @escaping (Date) -> MonthHeader,
         @ViewBuilder weekdayHeader: @escaping (String) -> WeekdayHeader
    ) {
        // Account for small input interval (eg just a few days in the middle of the month)
        let extendedStart = Calendar.current.dateInterval(of: .month, for: interval.start)!
        let extendedEnd = Calendar.current.dateInterval(of: .month, for: interval.end)!
        self.interval = DateInterval(start: extendedStart.start, end: extendedEnd.end)
        
        self._selection = selection
        self.canSelect = canSelect
        self.dayCell = dayCell
        self.monthHeader = monthHeader
        self.weekdayHeader = weekdayHeader
    }
    
    private var months: [Date] {
        calendar.generateDates(in: interval, matching: DateComponents(day: 1))
    }
    
    var body: some View {
        ScrollView(.vertical) {
            LazyVStack {
                ForEach(months, id: \.self) { month in
                    MonthView(month: month,
                              selection: $selection,
                              canSelect: canSelect,
                              dayCell: dayCell,
                              monthHeader: monthHeader,
                              weekdayHeader: weekdayHeader)
                    .id("month_view_\(month)")
                }
                .padding()
            }
        }
    }
}

struct MonthView<DayCell, MonthHeader, WeekdayHeader>: View where DayCell: View, MonthHeader: View, WeekdayHeader: View {
    @Environment(\.calendar) private var calendar
    @Binding private var selection: Date?
    private let canSelect: (Date) -> Bool
    
    private let month: Date
    private let dayCell: (Date) -> DayCell
    private let monthHeader: (Date) -> MonthHeader
    private let weekdayHeader: (String) -> WeekdayHeader
    
    init(
        month: Date,
        selection: Binding<Date?>,
        canSelect: @escaping (Date) -> Bool = { _ in true },
        @ViewBuilder dayCell: @escaping (Date) -> DayCell,
        @ViewBuilder monthHeader: @escaping (Date) -> MonthHeader,
        @ViewBuilder weekdayHeader: @escaping (String) -> WeekdayHeader
    ) {
        self.month = month
        self._selection = selection
        self.canSelect = canSelect
        self.dayCell = dayCell
        self.monthHeader = monthHeader
        self.weekdayHeader = weekdayHeader
    }
    
    private var days: [Date] {
        calendar.generateDates(in: extendedMonthInterval(from: month),
                               matching: DateComponents(hour: 0))
    }
    
    private func extendedMonthInterval(from startDate: Date) -> DateInterval? {
        guard let monthInterval = calendar.dateInterval(of: .month, for: startDate),
              let extendedStart = calendar.dateInterval(of: .weekOfYear, for: monthInterval.start)?.start
        else { return nil }
        
        return DateInterval(start: extendedStart, end: monthInterval.end)
    }
    
    private var weekdaySymbols: [String] {
        let symbols = calendar.weekdaySymbols // "Sun", "Mon", "Tue"…
        let firstWeekdayIndex = calendar.firstWeekday - 1 // Convert to 0-based index
        return Array(symbols[firstWeekdayIndex...] + symbols[..<firstWeekdayIndex])
    }
    
    var body: some View {
        VStack(spacing: 0) {
            monthHeader(month)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7)) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { index, name in
                    self.weekdayHeader(name)
                        .id("weekdayHeader_\(index)")
                }
                
                ForEach(days, id: \.self) { date in
                    let belongsInMonth = self.calendar.isDate(self.month, equalTo: date, toGranularity: .month)
                    if belongsInMonth {
                        Button {
                            selection = date
                        } label: {
                            self.dayCell(date)
                        }
                        .buttonStyle(.plain)
                        .disabled(!canSelect(date))
                    } else {
                        Color.clear
                    }
                }
            }
        }
    }
}

extension Calendar {
    func generateDates(
        in interval: DateInterval?,
        matching components: DateComponents
    ) -> [Date] {
        guard let interval else {
            return []
        }
        
        var dates: [Date] = []
        if self.date(interval.start, matchesComponents: components) {
            dates.append(interval.start)
        }
        
        enumerateDates(
            startingAfter: interval.start,
            matching: components,
            matchingPolicy: .nextTime
        ) { date, _, stop in
            if let date = date {
                if date < interval.end {
                    dates.append(date)
                } else {
                    stop = true
                }
            }
        }
        
        return dates
    }
}
