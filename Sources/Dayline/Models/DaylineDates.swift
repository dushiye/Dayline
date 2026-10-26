import Foundation
import DaylineCore

enum DaylineDates {
    static func isToday(_ task: DayTask, now: Date = Date(), calendar: Calendar = .current) -> Bool {
        occurs(task, on: now, calendar: calendar)
    }

    static func isOverdue(_ task: DayTask, now: Date = Date(), calendar: Calendar = .current) -> Bool {
        DaylineScheduling.isOverdue(isCompleted: task.isCompleted, dueDate: task.dueDate, now: now, calendar: calendar)
    }

    static func isUnfinishedPast(_ task: DayTask, now: Date = Date(), calendar: Calendar = .current) -> Bool {
        DaylineScheduling.isUnfinishedPast(isCompleted: task.isCompleted, scheduledDate: task.scheduledDate, now: now, calendar: calendar)
    }

    static func isInbox(_ task: DayTask) -> Bool {
        DaylineScheduling.isInbox(areaID: task.areaID, scheduledDate: task.scheduledDate, goalID: task.goalID)
    }

    static func occurs(_ task: DayTask, on date: Date, calendar: Calendar = .current) -> Bool {
        DaylineScheduling.occurs(scheduledDate: task.scheduledDate, dueDate: task.dueDate, on: date, calendar: calendar)
    }

    static func nextOccurrence(after anchor: Date, rule: RepeatRule, now: Date = Date(), calendar: Calendar = .current) -> Date? {
        DaylineScheduling.nextOccurrence(after: anchor, rule: rule, now: now, calendar: calendar)
    }
}
