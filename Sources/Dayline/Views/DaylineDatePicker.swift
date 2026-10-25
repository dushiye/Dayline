import SwiftUI

/// Calendar-day arithmetic for the date picker. Stored values remain `Date`;
/// a chosen day is the start of that day in the calendar used to select it.
enum DaylineDateSelection {
    static func startOfDay(_ date: Date, calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: date)
    }

    static func monthStart(_ date: Date, calendar: Calendar = .current) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date))
            ?? startOfDay(date, calendar: calendar)
    }

    static func byAddingMonths(_ value: Int, to date: Date, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .month, value: value, to: monthStart(date, calendar: calendar))
            ?? monthStart(date, calendar: calendar)
    }

    static func byAddingDays(_ value: Int, to date: Date, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: value, to: startOfDay(date, calendar: calendar))
            ?? startOfDay(date, calendar: calendar)
    }

    static func isSameDay(_ lhs: Date, _ rhs: Date, calendar: Calendar = .current) -> Bool {
        calendar.isDate(lhs, inSameDayAs: rhs)
    }

    static func isInMonth(_ day: Date, month: Date, calendar: Calendar = .current) -> Bool {
        calendar.isDate(day, equalTo: month, toGranularity: .month)
    }

    static func dayKey(_ date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    /// Six weeks, aligned to `calendar.firstWeekday`, including leading and trailing days.
    static func gridDays(in month: Date, calendar: Calendar = .current) -> [Date] {
        let start = monthStart(month, calendar: calendar)
        let weekday = calendar.component(.weekday, from: start)
        let leading = (weekday - calendar.firstWeekday + 7) % 7
        let origin = byAddingDays(-leading, to: start, calendar: calendar)
        return (0..<42).map { byAddingDays($0, to: origin, calendar: calendar) }
    }
}

struct DaylineDateField: View {
    @Binding var date: Date
    var label: String
    var identifier: String
    var allowsClear: Bool = true
    var previewEnvironmentKey: String? = nil
    var onClear: () -> Void = {}
    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                    .font(.system(size: 11, weight: .medium))
                Text(date.formatted(.dateTime.year().month().day()))
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.primary.opacity(0.055), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityValue(date.formatted(.dateTime.year().month().day().weekday(.wide)))
        .accessibilityIdentifier("\(identifier)Button")
        .help("选择\(label)")
        .onAppear {
            guard let previewEnvironmentKey else { return }
            let process = ProcessInfo.processInfo
            guard process.arguments.contains("--qa-store"), process.environment[previewEnvironmentKey] == "1" else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { isPresented = true }
        }
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            DaylineDateCalendar(date: $date, label: label, identifier: identifier, allowsClear: allowsClear, onClear: {
                onClear()
                isPresented = false
            }, onCommit: {
                isPresented = false
            })
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .frame(width: 344)
        }
    }
}

private struct DaylineDateCalendar: View {
    @Binding var date: Date
    var label: String
    var identifier: String
    var allowsClear: Bool
    var onClear: () -> Void
    var onCommit: () -> Void
    @State private var visibleMonth: Date
    @State private var keyboardDay: Date
    @FocusState private var calendarFocused: Bool
    @State private var hoveredKey: String?

    private var calendar: Calendar { .current }

    init(date: Binding<Date>, label: String, identifier: String, allowsClear: Bool, onClear: @escaping () -> Void, onCommit: @escaping () -> Void) {
        _date = date
        self.label = label
        self.identifier = identifier
        self.allowsClear = allowsClear
        self.onClear = onClear
        self.onCommit = onCommit
        let calendar = Calendar.current
        let start = DaylineDateSelection.startOfDay(date.wrappedValue, calendar: calendar)
        _visibleMonth = State(initialValue: DaylineDateSelection.monthStart(start, calendar: calendar))
        _keyboardDay = State(initialValue: start)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            weekdayRow
            dayGrid
            Divider().opacity(0.7)
            footer
        }
        .focusable()
        .focused($calendarFocused)
        .focusEffectDisabled()
        .onAppear { calendarFocused = true }
        .onMoveCommand { direction in
            switch direction {
            case .left: moveKeyboard(by: -1)
            case .right: moveKeyboard(by: 1)
            case .up: moveKeyboard(by: -7)
            case .down: moveKeyboard(by: 7)
            default: break
            }
        }
        .onKeyPress(.leftArrow) { moveKeyboard(by: -1); return .handled }
        .onKeyPress(.rightArrow) { moveKeyboard(by: 1); return .handled }
        .onKeyPress(.upArrow) { moveKeyboard(by: -7); return .handled }
        .onKeyPress(.downArrow) { moveKeyboard(by: 7); return .handled }
        .onKeyPress(.return) { commit(keyboardDay); return .handled }
        .onKeyPress(.space) { commit(keyboardDay); return .handled }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("\(identifier)Calendar")
        .accessibilityLabel("\(label)日历")
    }

    private var header: some View {
        HStack(spacing: 8) {
            monthButton("chevron.left", label: "上个月", identifier: "\(identifier)PreviousMonth") {
                visibleMonth = DaylineDateSelection.byAddingMonths(-1, to: visibleMonth, calendar: calendar)
            }
            Spacer(minLength: 8)
            Text(visibleMonth.formatted(.dateTime.year().month()))
                .font(.system(size: 16, weight: .semibold))
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
            monthButton("chevron.right", label: "下个月", identifier: "\(identifier)NextMonth") {
                visibleMonth = DaylineDateSelection.byAddingMonths(1, to: visibleMonth, calendar: calendar)
            }
        }
    }

    private var weekdayRow: some View {
        let symbols = orderedWeekdaySymbols
        return HStack(spacing: 4) {
            ForEach(Array(symbols.enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .frame(width: 40, height: 18)
            }
        }
        .accessibilityHidden(true)
    }

    private var dayGrid: some View {
        let columns = Array(repeating: GridItem(.fixed(40), spacing: 4), count: 7)
        let days = DaylineDateSelection.gridDays(in: visibleMonth, calendar: calendar)
        return LazyVGrid(columns: columns, spacing: 4) {
            ForEach(days, id: \.timeIntervalSinceReferenceDate) { day in
                dayCell(day)
            }
        }
    }

    private var footer: some View {
        HStack {
            Button("今天") { commit(.now) }
                .buttonStyle(.borderless)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(DaylineDesign.accent)
                .accessibilityIdentifier("\(identifier)Today")
            Spacer()
            if allowsClear {
                Button("清除日期") { onClear() }
                    .buttonStyle(.borderless)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("\(identifier)Clear")
            }
        }
        .padding(.top, 2)
    }

    private func dayCell(_ day: Date) -> some View {
        let key = DaylineDateSelection.dayKey(day, calendar: calendar)
        let inMonth = DaylineDateSelection.isInMonth(day, month: visibleMonth, calendar: calendar)
        let selected = DaylineDateSelection.isSameDay(day, date, calendar: calendar)
        let today = DaylineDateSelection.isSameDay(day, .now, calendar: calendar)
        let keyboard = DaylineDateSelection.isSameDay(day, keyboardDay, calendar: calendar)
        let number = calendar.component(.day, from: day)
        return Button {
            commit(day)
        } label: {
            ZStack {
                if keyboard && !selected {
                    Circle().strokeBorder(Color.primary.opacity(0.28), lineWidth: 1)
                        .frame(width: 34, height: 34)
                }
                if today && selected {
                    Circle().strokeBorder(DaylineDesign.accent.opacity(0.45), lineWidth: 1.5)
                        .frame(width: 36, height: 36)
                } else if today {
                    Circle().strokeBorder(DaylineDesign.accent, lineWidth: 1.5)
                        .frame(width: 32, height: 32)
                }
                if selected {
                    Circle().fill(selectionFill).frame(width: 32, height: 32)
                } else if hoveredKey == key {
                    Circle().fill(Color.primary.opacity(0.06)).frame(width: 32, height: 32)
                }
                Text("\(number)")
                    .font(.system(size: 14, weight: selected ? .semibold : .regular, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(selected ? Color.white : (inMonth ? Color.primary : Color.secondary.opacity(0.72)))
            }
            .frame(width: 40, height: 40)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in hoveredKey = hovering ? key : (hoveredKey == key ? nil : hoveredKey) }
        .accessibilityLabel(accessibilityLabel(for: day, today: today, selected: selected))
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("\(identifier)Day-\(key)")
        .help(accessibilityLabel(for: day, today: today, selected: selected))
    }

    private var selectionFill: Color { Color(red: 0.29, green: 0.43, blue: 0.88) }

    private func monthButton(_ symbol: String, label: String, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .background(Color.primary.opacity(0.05), in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityIdentifier(identifier)
    }

    private var orderedWeekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let start = calendar.firstWeekday - 1
        return (0..<7).map { symbols[(start + $0) % symbols.count] }
    }

    private func accessibilityLabel(for day: Date, today: Bool, selected: Bool) -> String {
        var text = day.formatted(.dateTime.year().month().day().weekday(.wide))
        if today { text += "，今天" }
        if selected { text += "，已选择" }
        return text
    }

    private func moveKeyboard(by days: Int) {
        let next = DaylineDateSelection.byAddingDays(days, to: keyboardDay, calendar: calendar)
        keyboardDay = next
        if !DaylineDateSelection.isInMonth(next, month: visibleMonth, calendar: calendar) {
            visibleMonth = DaylineDateSelection.monthStart(next, calendar: calendar)
        }
    }

    private func commit(_ day: Date) {
        date = DaylineDateSelection.startOfDay(day, calendar: calendar)
        onCommit()
    }
}
