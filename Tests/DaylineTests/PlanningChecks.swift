import Foundation
#if canImport(Dayline)
@testable import Dayline
#endif

enum PlanningChecks {
    struct Failure: Error, CustomStringConvertible { let description: String }
    static let zone = TimeZone(identifier: "Asia/Shanghai")!
    static func date(_ day: Int, _ hour: Int = 12, _ minute: Int = 0) -> Date {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = zone
        return calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))!
    }
    static func key(_ day: Int) -> String { String(format: "2026-10-%02d", day) }
    static func event(_ id: UUID, _ kind: PlanningEventKind, _ observed: Int,
                      _ planned: Int?, _ new: Int? = nil, hour: Int = 12,
                      completed: Bool = false) -> PlanningEventRecord {
        PlanningEventRecord(taskID: id, kind: kind, occurredAt: date(observed, hour),
            dayKey: planned.map(key), newDayKey: new.map(key), timeZoneID: zone.identifier,
            taskTitle: "测试", wasCompleted: completed)
    }
    static func check(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        if !condition() { throw Failure(description: message) }
    }
    static func report(_ events: [PlanningEventRecord], now: Int = 25) -> PlanningReport {
        PlanningAnalysis.analyze(events: events, asOf: date(now), timeZone: zone)
    }
    static func day(_ result: PlanningReport, _ day: Int) -> PlanningDaySummary {
        result.days.first { $0.dayKey == key(day) } ?? PlanningDaySummary(dayKey: key(day))
    }
    static func history(_ count: Int) -> [PlanningEventRecord] {
        (2..<(2 + count)).flatMap { value -> [PlanningEventRecord] in
            let id = UUID()
            return [event(id, .planned, value - 1, value), event(id, .completed, value, value, completed: true)]
        }
    }

    static func fourteenDays() throws {
        let result = report(history(14))
        try check(result.recent7.dayCount == 7 && result.recent14.dayCount == 14 && result.recent30.dayCount == 14, "valid-day windows")
        try check(result.recent14.planned == 14 && result.recent14.actualCompleted == 14 && result.recent14.originalCompleted == 14, "14-day metrics")
        try check(result.recent14.completionRate == 1 && result.coach.hasEnoughHistory && result.coach.basisDayCount == 14, "14-day coach")
        let json = try JSONEncoder().encode(history(14))
        let decoded = try JSONDecoder().decode([PlanningEventRecord].self, from: json)
        try check(decoded.count == 28, "event JSON roundtrip")
    }
    static func insufficientAndCurrentDay() throws {
        let result = report(history(6))
        try check(!result.coach.hasEnoughHistory && result.coach.basisDayCount == 6, "fewer than seven")
        let today = event(UUID(), .planned, 24, 25)
        let future = event(UUID(), .planned, 24, 26)
        let withFuture = report(history(6) + [today, future])
        try check(withFuture.recent14.dayCount == 6 && !withFuture.coach.hasEnoughHistory, "today and future excluded")
        try check(report(history(7)).coach.hasEnoughHistory, "seven threshold")
    }
    static func noFabricatedBaseline() throws {
        let overdue = event(UUID(), .baseline, 20, 1)
        let partial = event(UUID(), .baseline, 20, 20)
        let future = event(UUID(), .baseline, 20, 21)
        let done = event(UUID(), .baseline, 20, 22, completed: true)
        let result = report([overdue, partial, future, done])
        try check(day(result, 1).planned == 0 && day(result, 22).planned == 0, "no retrospective or already-complete baseline")
        try check(day(result, 20).hasPartialBaseline && !day(result, 20).isEffectivePlanDay, "partial baseline excluded")
        try check(result.recent14.dayCount == 1 && result.recent14.planned == 1 && result.recent14.actualCompleted == 0, "only observed future baseline valid")
        let backdated = report([event(UUID(), .planned, 20, 1)])
        try check(day(backdated, 1).addedToday == 1 && backdated.recent14.dayCount == 0, "backdated assignment does not establish earlier observed history")
    }
    static func rescheduleDeleteAndUndo() throws {
        let id = UUID()
        let initial = event(id, .planned, 1, 2)
        let moved = event(id, .rescheduled, 2, 2, 3)
        let back = event(id, .rescheduled, 2, 3, 2, hour: 13)
        let deleted = event(id, .deleted, 2, 2, hour: 14)
        let restored = event(id, .planned, 2, 2, hour: 15)
        try check(day(report([initial, moved]), 2).activelyRescheduled == 1, "move tracked")
        let returned = report([initial, moved, back])
        try check(day(returned, 2).activelyRescheduled == 0 && day(returned, 2).planned == 1 && day(returned, 3).planned == 0, "undo move restores original without future ghost")
        let removed = day(report([initial, moved, back, deleted]), 2)
        try check(removed.deleted == 1 && removed.planned == 1, "delete preserves denominator")
        let undone = day(report([initial, moved, back, deleted, restored]), 2)
        try check(undone.deleted == 0 && undone.originalPlanned == 1 && undone.addedToday == 0, "undo delete preserves identity")
    }
    static func additionsAndActualCompletion() throws {
        let original = UUID(), late = UUID(), unscheduled = UUID()
        let events = [event(original, .planned, 1, 2), event(original, .completed, 3, 2, completed: true),
            event(late, .planned, 2, 2), event(late, .completed, 2, 2, hour: 14, completed: true),
            event(unscheduled, .completed, 2, nil, completed: true)]
        let result = report(events)
        try check(day(result, 2).planned == 2 && day(result, 2).addedToday == 1 && day(result, 2).originalPlanned == 1, "late adds separated")
        try check(day(result, 2).actualCompleted == 2 && day(result, 3).actualCompleted == 1 && day(result, 2).originalCompleted == 0, "actual occurrence date distinct from original plan")
    }
    static func completionUndoDedupAndRecurrence() throws {
        let id = UUID(), second = UUID(), source = UUID()
        var first = event(id, .planned, 1, 2); first.recurrenceSourceID = source
        var another = event(second, .planned, 1, 2); another.recurrenceSourceID = source
        let complete = event(id, .completed, 2, 2, completed: true)
        let reopened = event(id, .reopened, 2, 2, hour: 13)
        let repeated = event(id, .completed, 3, 2, completed: true)
        let result = report([first, first, another, complete, complete])
        try check(day(result, 2).planned == 2 && day(result, 2).actualCompleted == 1, "event dedup; recurrence occurrences distinct")
        try check(day(report([first, complete, reopened]), 2).actualCompleted == 0, "undo completion")
        let redone = report([first, complete, reopened, repeated])
        try check(day(redone, 2).actualCompleted == 0 && day(redone, 3).actualCompleted == 1, "redo uses new observed date")
        try check(day(report([first, complete, repeated]), 2).actualCompleted == 1 && day(report([first, complete, repeated]), 3).actualCompleted == 0, "repeated completion observation does not shift date")
    }
    static func midnightCapturedZoneAndAsOf() throws {
        let id = UUID()
        var assigned = event(id, .planned, 1, 2, hour: 23)
        assigned.occurredAt = date(1, 23, 59)
        let complete = event(id, .completed, 2, 2, hour: 0, completed: true)
        let west = TimeZone(identifier: "America/Los_Angeles")!
        let result = PlanningAnalysis.analyze(events: [complete, assigned], asOf: date(3), timeZone: west)
        try check(day(result, 2).originalPlanned == 1 && day(result, 2).actualCompleted == 1, "captured zone survives travel; timestamp sort")
        let before = PlanningAnalysis.analyze(events: [assigned, complete], asOf: date(1, 23, 59), timeZone: zone)
        try check(day(before, 2).actualCompleted == 0 && before.recent14.dayCount == 0, "asOf filters future observations")
    }
    static func coachSeparatesCauses() throws {
        var moves: [PlanningEventRecord] = [], adds: [PlanningEventRecord] = []
        for value in 2...15 {
            let id = UUID()
            moves += [event(id, .planned, value - 1, value), event(id, .rescheduled, value, value, 26)]
            adds += [event(UUID(), .planned, value, value)]
        }
        try check(report(moves).coach.title == "为主动调整留出空间", "reschedule-specific coaching")
        try check(report(adds).coach.title == "为当天新增预留容量", "addition-specific coaching")
        let many = (0..<100).map { _ in event(UUID(), .planned, 15, 16) }
        try check(report(history(14) + many).coach.title == "保持可持续的节奏", "one poor day cannot trigger reduce-commitment advice")
        let poor = (2...15).map { event(UUID(), .planned, $0 - 1, $0) }
        try check(report(poor).coach.title == "试着缩小每日承诺", "sustained pattern yields bounded advice")
    }
    static func gapsAndThirtyDayWindow() throws {
        let result = report([event(UUID(), .planned, 1, 2), event(UUID(), .planned, 21, 22)])
        try check(result.recent7.dayCount == 2 && result.recent7.days.map(\.dayKey) == [key(2), key(22)], "windows use valid days, not elapsed calendar days")
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = zone
        let events = (0..<40).map { offset -> PlanningEventRecord in
            let planDate = calendar.date(byAdding: .day, value: -offset - 1, to: date(25))!
            return PlanningEventRecord(taskID: UUID(), kind: .planned,
                occurredAt: calendar.date(byAdding: .day, value: -1, to: planDate)!,
                dayKey: PlanningAnalysis.dayKey(for: planDate, timeZone: zone), timeZoneID: zone.identifier, taskTitle: "Window")
        }
        try check(report(events).recent30.dayCount == 30 && report(events).coach.basisDayCount == 14, "30-day cap and 14-day coach cap")
    }
    static func todayCapacityThreshold() throws {
        let base = history(14)
        let today = (0..<4).map { _ in event(UUID(), .planned, 24, 25) }
        try check(report(base + today).coach.title == "今日计划可能偏满", "four tasks exceed conservative capacity of three")
        try check(report(base + Array(today.prefix(3))).coach.title != "今日计划可能偏满", "at threshold does not overreact")
        try check(!report(history(6) + today).coach.hasEnoughHistory, "capacity requires seven days")
        let move = event(today[0].taskID, .rescheduled, 25, 25, 26, hour: 10)
        try check(report(base + today + [move]).coach.title != "今日计划可能偏满", "moved assignments excluded from today load")
        let delete = event(today[0].taskID, .deleted, 25, 25, hour: 10)
        try check(report(base + today + [delete]).coach.title != "今日计划可能偏满", "deleted assignments excluded from today load")
        let completed = event(today[0].taskID, .completed, 25, 25, hour: 10, completed: true)
        try check(report(base + today + [completed]).coach.title == "今日计划可能偏满", "today completed work remains part of today's total load")
        let prior = event(today[0].taskID, .completed, 24, 25, hour: 14, completed: true)
        try check(report(base + today + [prior]).coach.title != "今日计划可能偏满", "previously finished task adds no today workload")
    }
    static func finishedTaskCannotInflateFutureAdherence() throws {
        let id = UUID()
        let result = report([event(id, .planned, 1, 2), event(id, .completed, 2, 2, completed: true),
                             event(id, .rescheduled, 3, 2, 4, completed: true)])
        try check(day(result, 2).originalCompleted == 1, "real original completion survives later schedule edit")
        try check(day(result, 4).originalCompleted == 0, "moving a completed task cannot fabricate another day's completion")
        try check(day(result, 4).planned == 0, "moving already finished work creates no new work commitment")
    }
    static func reopenedCompletedBaselineBecomesObservedPlan() throws {
        let id = UUID()
        let baseline = event(id, .baseline, 2, 2, completed: true)
        let reopened = event(id, .reopened, 2, 2, hour: 13)
        let sameDay = day(report([baseline, reopened]), 2)
        try check(sameDay.planned == 1 && sameDay.addedToday == 1 && sameDay.originalPlanned == 0,
                  "reopened completed baseline becomes one same-day addition")
        try check(sameDay.actualCompleted == 0 && sameDay.originalCompleted == 0,
                  "reopen must not infer baseline completion history")

        let moved = event(id, .rescheduled, 2, 2, 4, hour: 13, completed: true)
        let reopenedAfterMove = event(id, .reopened, 2, 4, hour: 14)
        let newDate = report([baseline, moved, reopenedAfterMove])
        try check(day(newDate, 2).planned == 0 && day(newDate, 4).planned == 1 && day(newDate, 4).originalPlanned == 1,
                  "reopen after completed move uses the new plan date")

        let planned = event(id, .planned, 1, 2)
        let completed = event(id, .completed, 2, 2, completed: true)
        let ordinary = day(report([planned, completed, reopened, reopened]), 2)
        try check(ordinary.planned == 1 && ordinary.originalPlanned == 1 && ordinary.addedToday == 0,
                  "ordinary completion undo retains original assignment without double counting")
        let backdated = report([event(id, .baseline, 3, 2, completed: true), event(id, .reopened, 3, 2, hour: 14)])
        try check(day(backdated, 2).planned == 1 && !day(backdated, 2).isEffectivePlanDay,
                  "reopening an overdue baseline never establishes earlier observed history")
    }
    static let all: [(String, () throws -> Void)] = [
        ("Synthetic 14 effective days + Codable", fourteenDays),
        ("Insufficient history and current/future exclusion", insufficientAndCurrentDay),
        ("Baseline migration never fabricates history", noFabricatedBaseline),
        ("Reschedule, delete and undo identity", rescheduleDeleteAndUndo),
        ("Late additions and actual completion dates", additionsAndActualCompletion),
        ("Completion undo, dedup and recurrence identity", completionUndoDedupAndRecurrence),
        ("Midnight, captured timezone and asOf", midnightCapturedZoneAndAsOf),
        ("Coach distinguishes patterns and ignores one poor day", coachSeparatesCauses),
        ("Effective-day gaps and 30-day cap", gapsAndThirtyDayWindow),
        ("Today's capacity threshold and active workload", todayCapacityThreshold),
        ("Finished tasks cannot inflate future adherence", finishedTaskCannotInflateFutureAdherence),
        ("Reopened completed baseline becomes observed plan", reopenedCompletedBaselineBecomesObservedPlan)
    ]
}
