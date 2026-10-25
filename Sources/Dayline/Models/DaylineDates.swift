import Foundation

enum DaylineDates {
    static func isToday(_ task: DayTask, now: Date = Date(), calendar: Calendar = .current) -> Bool {
        occurs(task, on: now, calendar: calendar)
    }

    static func isOverdue(_ task: DayTask, now: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard !task.isCompleted, let due = task.dueDate else { return false }
        return due < calendar.startOfDay(for: now)
    }

    static func isUnfinishedPast(_ task: DayTask, now: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard !task.isCompleted, let scheduled = task.scheduledDate else { return false }
        return scheduled < calendar.startOfDay(for: now)
    }

    static func isInbox(_ task: DayTask) -> Bool {
        task.areaID == nil && task.scheduledDate == nil && task.goalID == nil
    }

    static func occurs(_ task: DayTask, on date: Date, calendar: Calendar = .current) -> Bool {
        // A single Boolean predicate means a task scheduled AND due today is counted once.
        (task.scheduledDate.map { calendar.isDate($0, inSameDayAs: date) } ?? false)
            || (task.dueDate.map { calendar.isDate($0, inSameDayAs: date) } ?? false)
    }

    /// Completion-driven recurrence creates one future occurrence. Missed dates are skipped,
    /// while weekly rules preserve their original weekday; existing past tasks remain visible.
    static func nextOccurrence(after anchor: Date, rule: RepeatRule, now: Date = Date(), calendar: Calendar = .current) -> Date? {
        guard rule != .none else { return nil }
        let start = calendar.startOfDay(for: anchor)
        let today = calendar.startOfDay(for: now)
        let interval = rule == .weekly ? 7 : 1
        let difference = max(0, calendar.dateComponents([.day], from: start, to: today).day ?? 0)
        let steps = max(1, difference / interval + 1)
        return calendar.date(byAdding: .day, value: steps * interval, to: start)
    }
}
