import Foundation
#if canImport(Dayline)
@testable import Dayline
#endif

enum DatePickerChecks {
    private static func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        if !condition() { throw CheckFailure(description: message) }
    }

    private static func calendar(_ zone: String, firstWeekday: Int? = nil) -> Calendar {
        var result = Calendar(identifier: .gregorian)
        result.timeZone = TimeZone(identifier: zone)!
        if let firstWeekday { result.firstWeekday = firstWeekday }
        return result
    }

    private static func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12, _ minute: Int = 0, calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    static func gridAndTimeZone() throws {
        let shanghai = calendar("Asia/Shanghai", firstWeekday: 2)
        let october = date(2026, 10, 15, calendar: shanghai)
        let days = DaylineDateSelection.gridDays(in: october, calendar: shanghai)
        let keys = days.map { DaylineDateSelection.dayKey($0, calendar: shanghai) }
        try require(days.count == 42 && Set(keys).count == 42, "Month grid must contain 42 distinct days")
        try require(keys == keys.sorted(), "Month grid must stay in calendar order")
        try require(shanghai.component(.weekday, from: days[0]) == shanghai.firstWeekday, "Grid must start on the calendar's first weekday")
        try require(DaylineDateSelection.dayKey(days[3], calendar: shanghai) == "2026-10-01", "October 2026 must begin on the fourth cell when weeks start Monday")
        try require(DaylineDateSelection.isInMonth(days[3], month: october, calendar: shanghai), "October 1 must belong to the displayed month")
        try require(!DaylineDateSelection.isInMonth(days[0], month: october, calendar: shanghai), "Leading September day must stay outside October")

        let lateEvening = date(2026, 10, 25, 23, 30, calendar: shanghai)
        let stored = DaylineDateSelection.startOfDay(lateEvening, calendar: shanghai)
        try require(DaylineDateSelection.dayKey(stored, calendar: shanghai) == "2026-10-25", "Late evening must stay on the same Shanghai day")
        let losAngeles = calendar("America/Los_Angeles")
        try require(DaylineDateSelection.dayKey(lateEvening, calendar: losAngeles) == "2026-10-25", "2026-10-25 23:30 in Shanghai is still that calendar day in Los Angeles")
        let afterMidnightThere = date(2026, 10, 25, 2, 0, calendar: shanghai)
        try require(DaylineDateSelection.dayKey(afterMidnightThere, calendar: shanghai) == "2026-10-25", "Shanghai midnight must not roll backward")
        try require(DaylineDateSelection.dayKey(afterMidnightThere, calendar: losAngeles) == "2026-10-24", "The same instant must keep the Los Angeles calendar day")

        for (month, day, hours) in [(3, 8, 23), (11, 1, 25)] {
            let sample = date(2026, month, day, 23, 30, calendar: losAngeles)
            let start = DaylineDateSelection.startOfDay(sample, calendar: losAngeles)
            let next = DaylineDateSelection.byAddingDays(1, to: start, calendar: losAngeles)
            try require(DaylineDateSelection.dayKey(start, calendar: losAngeles) == String(format: "2026-%02d-%02d", month, day), "DST day was shifted")
            try require(losAngeles.component(.day, from: next) == day + 1, "The next calendar day was lost across DST")
            try require(Int(next.timeIntervalSince(start) / 3600) == hours, "DST fixture no longer spans \(hours) hours")
        }

        let shifted = DaylineDateSelection.byAddingMonths(1, to: october, calendar: shanghai)
        try require(DaylineDateSelection.dayKey(shifted, calendar: shanghai) == "2026-11-01", "Month navigation must land on the first of the next month")
        let back = DaylineDateSelection.byAddingMonths(-1, to: shifted, calendar: shanghai)
        try require(DaylineDateSelection.isSameDay(back, DaylineDateSelection.monthStart(october, calendar: shanghai), calendar: shanghai), "Month navigation must be reversible")
    }

    @MainActor
    static func goalDateRoundTrip() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("Dayline-DatePicker-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("Dayline.store")
        let shanghai = calendar("Asia/Shanghai")
        let chosen = DaylineDateSelection.startOfDay(date(2026, 6, 15, 23, 45, calendar: shanghai), calendar: shanghai)
        let created = try DaylineStore(container: DaylineStore.makeContainer(url: url))
        let goal = try unwrap(created.addGoal(title: "隔离日期目标", kind: .longTerm, areaID: created.areas.first?.id, targetDate: chosen), "Goal with a target date was not created")
        let goalID = goal.id
        let task = created.addTask(title: "无关任务", goalID: goalID)
        try require(task != nil && created.errorMessage == nil, "Adding an unrelated task failed")
        created.save()
        try require(created.errorMessage == nil, "Saving the isolated date fixture failed")

        let reopened = try DaylineStore(container: DaylineStore.makeContainer(url: url))
        let loaded = try unwrap(reopened.goals.first { $0.id == goalID }, "Reopen lost the goal")
        try require(loaded.targetDate != nil && shanghai.isDate(loaded.targetDate!, inSameDayAs: chosen), "Reopen shifted the goal date")
        try require(reopened.tasks.count == 1 && reopened.tasks[0].goalID == goalID, "Date save changed unrelated tasks")

        loaded.targetDate = DaylineDateSelection.startOfDay(date(2026, 12, 1, 0, 30, calendar: shanghai), calendar: shanghai)
        reopened.save()
        try require(reopened.errorMessage == nil, "Updating the goal date failed")
        let updated = try DaylineStore(container: DaylineStore.makeContainer(url: url))
        let moved = try unwrap(updated.goals.first { $0.id == goalID }?.targetDate, "Updated date was cleared")
        try require(DaylineDateSelection.dayKey(moved, calendar: shanghai) == "2026-12-01", "Updated goal date did not survive reopen")

        updated.goals[0].targetDate = nil
        updated.save()
        let cleared = try DaylineStore(container: DaylineStore.makeContainer(url: url))
        try require(cleared.goals.first { $0.id == goalID }?.targetDate == nil, "Clearing the goal date did not persist")
        try require(cleared.tasks.count == 1, "Clearing a goal date changed tasks")
    }

    private static func unwrap<T>(_ value: T?, _ message: String) throws -> T {
        guard let value else { throw CheckFailure(description: message) }
        return value
    }
}
