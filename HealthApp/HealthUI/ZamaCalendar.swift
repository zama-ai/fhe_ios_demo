
import SwiftUI

#Preview {
    @Previewable @State var selection: Date?
    let calendar = Calendar.current
    let currentYear: DateInterval = calendar.dateInterval(of: .year, for: Date())!
    let samples: [Date] = calendar.generateDates(in: currentYear, matching: DateComponents(day: 5))
    
    VStack {
        DatePicker("Selection:",
                   selection: .init(get: { selection ?? Date.now }, set: { selection = $0 }),
                   in: currentYear.start...currentYear.end,
                   displayedComponents: .date)
        
        ZamaCalendar(covering: currentYear,
                     selection: $selection,
                     canSelect: { samples.contains($0) })
    }
    .padding()
}

struct ZamaCalendar: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.locale) private var locale
    
    @Binding private var selection: Date?
    private let canSelect: (Date) -> Bool
    private let interval: DateInterval
    
    init(covering interval: DateInterval,
         selection: Binding<Date?>,
         canSelect: @escaping (Date) -> Bool
    ) {
        self.interval = interval
        self._selection = selection
        self.canSelect = canSelect
    }
    
    var body: some View {
        CalendarView(covering: interval,
                     selection: $selection,
                     canSelect: canSelect) { date in
            Text(String(calendar.component(.day, from: date)))
                .font(.caption)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.zamaYellow.opacity(selection == date ? 1 : 0))
                .overlay(alignment: .bottom) {
                    if canSelect(date) {
                        Circle()
                            .frame(width: 3)
                            .padding(.bottom, 3)
                    }
                }
        } monthHeader: { month in
            Text(month.formatted(.dateTime.month(.wide).year(.defaultDigits).locale(locale)).capitalized)
                .font(.title)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 16)
        } weekdayHeader: { column in
            Text(column.prefix(3))
                .textCase(.uppercase)
                .font(.caption2)
                .bold()
        }
        .background(Color.zamaYellowLight.ignoresSafeArea())
    }
}
