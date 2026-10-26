import Foundation

public enum DaylineDateSelection {
    public static func startOfDay(_ date: Date, calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: date)
    }

    public static func monthStart(_ date: Date, calendar: Calendar = .current) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date))
            ?? startOfDay(date, calendar: calendar)
    }

    public static func byAddingMonths(_ value: Int, to date: Date, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .month, value: value, to: monthStart(date, calendar: calendar))
            ?? monthStart(date, calendar: calendar)
    }

    public static func byAddingDays(_ value: Int, to date: Date, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: value, to: startOfDay(date, calendar: calendar))
            ?? startOfDay(date, calendar: calendar)
    }

    public static func isSameDay(_ lhs: Date, _ rhs: Date, calendar: Calendar = .current) -> Bool {
        calendar.isDate(lhs, inSameDayAs: rhs)
    }

    public static func isInMonth(_ day: Date, month: Date, calendar: Calendar = .current) -> Bool {
        calendar.isDate(day, equalTo: month, toGranularity: .month)
    }

    public static func dayKey(_ date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    public static func gridDays(in month: Date, calendar: Calendar = .current) -> [Date] {
        let start = monthStart(month, calendar: calendar)
        let weekday = calendar.component(.weekday, from: start)
        let leading = (weekday - calendar.firstWeekday + 7) % 7
        let origin = byAddingDays(-leading, to: start, calendar: calendar)
        return (0..<42).map { byAddingDays($0, to: origin, calendar: calendar) }
    }
}

public enum DaylineScheduling {
    public static func isOverdue(isCompleted: Bool, dueDate: Date?, now: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard !isCompleted, let due = dueDate else { return false }
        return due < calendar.startOfDay(for: now)
    }

    public static func isUnfinishedPast(isCompleted: Bool, scheduledDate: Date?, now: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard !isCompleted, let scheduled = scheduledDate else { return false }
        return scheduled < calendar.startOfDay(for: now)
    }

    public static func isInbox(areaID: UUID?, scheduledDate: Date?, goalID: UUID?) -> Bool {
        areaID == nil && scheduledDate == nil && goalID == nil
    }

    public static func occurs(scheduledDate: Date?, dueDate: Date?, on date: Date, calendar: Calendar = .current) -> Bool {
        (scheduledDate.map { calendar.isDate($0, inSameDayAs: date) } ?? false)
            || (dueDate.map { calendar.isDate($0, inSameDayAs: date) } ?? false)
    }

    public static func nextOccurrence(after anchor: Date, rule: RepeatRule, now: Date = Date(), calendar: Calendar = .current) -> Date? {
        guard rule != .none else { return nil }
        let start = calendar.startOfDay(for: anchor)
        let today = calendar.startOfDay(for: now)
        let interval = rule == .weekly ? 7 : 1
        let difference = max(0, calendar.dateComponents([.day], from: start, to: today).day ?? 0)
        let steps = max(1, difference / interval + 1)
        return calendar.date(byAdding: .day, value: steps * interval, to: start)
    }

    /// The calendar day stays on the key captured in `timeZone`, even when `viewer` is elsewhere.
    public static func stableDayKey(_ date: Date, capturedIn timeZone: TimeZone) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return DaylineDateSelection.dayKey(date, calendar: calendar)
    }
}
