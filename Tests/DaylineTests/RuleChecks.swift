import Foundation
import DaylineCore
import SwiftData
import Observation
import DaylineData
#if canImport(Dayline) && !DAYLINE_SCRIPT_TEST
@testable import Dayline
#endif

struct CheckFailure: Error, CustomStringConvertible {
    let description: String
}

final class ObservationProbe: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    func signal() { lock.lock(); count += 1; lock.unlock() }
    var changes: Int { lock.lock(); defer { lock.unlock() }; return count }
}

@MainActor
enum RuleChecks {
    static func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        if !condition() { throw CheckFailure(description: message) }
    }

    static func store() throws -> DaylineStore {
        try DaylineStore(container: DaylineStore.makeContainer(inMemory: true))
    }

    nonisolated static func calendar(_ zone: String = "Asia/Shanghai") -> Calendar {
        var result = Calendar(identifier: .gregorian)
        result.timeZone = TimeZone(identifier: zone)!
        return result
    }

    nonisolated static func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12, _ minute: Int = 0, calendar: Calendar = calendar()) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    static func todayUsesEitherDateOnce() throws {
        let c = calendar(), now = date(2026, 10, 25)
        let s = try store()
        let scheduled = s.addTask(title: "Scheduled", scheduledDate: date(2026, 10, 25, 0))!
        let due = s.addTask(title: "Due", dueDate: date(2026, 10, 25, 23, 59))!
        let both = s.addTask(title: "Both", scheduledDate: now, dueDate: now)!
        _ = s.addTask(title: "Tomorrow", scheduledDate: date(2026, 10, 26))!
        let result = s.tasks.filter { DaylineDates.isToday($0, now: now, calendar: c) }
        try require(result.count == 3, "Today must use scheduled OR due and include a dual-date task once")
        try require(Set(result.map(\.id)) == Set([scheduled.id, due.id, both.id]), "Today IDs differ")
        try require(DaylineDates.occurs(both, on: now, calendar: c), "occurs should include a dual-date task")
        try require(!DaylineDates.occurs(both, on: date(2026, 10, 26), calendar: c), "occurs included wrong day")
    }

    static func overdueAndCarryoverAreDistinct() throws {
        let s = try store(), c = calendar(), now = date(2026, 10, 25)
        let oldDue = s.addTask(title: "Late", dueDate: date(2026, 10, 24, 23, 59))!
        let todayDue = s.addTask(title: "Today", dueDate: date(2026, 10, 25, 0))!
        let carry = s.addTask(title: "Carry", scheduledDate: date(2026, 10, 24))!
        try require(DaylineDates.isOverdue(oldDue, now: now, calendar: c), "Yesterday due must be overdue")
        try require(!DaylineDates.isOverdue(todayDue, now: now, calendar: c), "Due today is not overdue before midnight")
        try require(!DaylineDates.isOverdue(carry, now: now, calendar: c), "A past schedule alone is not an overdue deadline")
        try require(DaylineDates.isUnfinishedPast(carry, now: now, calendar: c), "Past schedule should be carryover")
        try require(!DaylineDates.isUnfinishedPast(oldDue, now: now, calendar: c), "Past due alone is not carryover")
        let originalSchedule = carry.scheduledDate
        try s.refresh()
        try require(carry.scheduledDate == originalSchedule, "Refresh silently moved a past schedule")
        s.toggleTask(oldDue); s.toggleTask(carry)
        try require(!DaylineDates.isOverdue(oldDue, now: now, calendar: c), "Completed task cannot be overdue")
        try require(!DaylineDates.isUnfinishedPast(carry, now: now, calendar: c), "Completed task cannot be carryover")
    }

    static func dstAndCalendarBoundaries() throws {
        let s = try store(), c = calendar("America/Los_Angeles")
        for (month, day, expectedHours) in [(3, 8, 23), (11, 1, 25)] {
            let now = date(2026, month, day, calendar: c)
            let start = c.startOfDay(for: now)
            let next = c.date(byAdding: .day, value: 1, to: start)!
            try require(Int(next.timeIntervalSince(start) / 3600) == expectedHours, "Fixture must span a DST transition")
            let task = s.addTask(title: "DST", scheduledDate: next.addingTimeInterval(-1), dueDate: start)!
            try require(DaylineDates.isToday(task, now: now, calendar: c), "Local day end omitted across DST")
            try require(!DaylineDates.isOverdue(task, now: now, calendar: c), "Local midnight should not be overdue")
            task.scheduledDate = next; task.dueDate = nil
            try require(!DaylineDates.isToday(task, now: now, calendar: c), "Next local midnight included across DST")
            task.dueDate = start.addingTimeInterval(-1)
            try require(DaylineDates.isOverdue(task, now: now, calendar: c), "Previous local day not overdue")
        }
        let instant = date(2026, 10, 25, 0, 30)
        let task = s.addTask(title: "Zone", scheduledDate: instant)!
        try require(DaylineDates.occurs(task, on: date(2026, 10, 24, 12, calendar: c), calendar: c), "Calendar time zone ignored")
    }

    static func inboxKeepsDueOnlyTasks() throws {
        let s = try store()
        let plain = s.addTask(title: "Plain")!, due = s.addTask(title: "Due only", dueDate: Date())!
        try require(DaylineDates.isInbox(plain) && DaylineDates.isInbox(due), "Due date alone must not remove Inbox task")
        plain.scheduledDate = Date()
        try require(!DaylineDates.isInbox(plain), "Scheduled task remains in Inbox")
        plain.scheduledDate = nil; plain.areaID = s.areas.first!.id
        try require(!DaylineDates.isInbox(plain), "Area task remains in Inbox")
        plain.areaID = nil; plain.goalID = s.addGoal(title: "Goal", kind: .shortTerm, areaID: nil)!.id
        try require(!DaylineDates.isInbox(plain), "Goal task remains in Inbox")
    }

    static func rejectsBlankAndTrimsTitles() throws {
        let s = try store(), initial = s.tasks.count
        try require(s.addTask(title: " \n\t ") == nil, "Blank task accepted")
        try require(s.addGoal(title: "\n ", kind: .longTerm, areaID: nil) == nil, "Blank goal accepted")
        try require(s.tasks.count == initial, "Blank input changed task count")
        try require(s.addTask(title: "  Read  ")?.title == "Read", "Task title not trimmed")
    }

    static func goalDeletionPreservesDescendantsAndTasks() throws {
        let s = try store()
        let parent = s.addGoal(title: "Parent", kind: .longTerm, areaID: nil)!
        let child = s.addGoal(title: "Child", kind: .shortTerm, areaID: nil, parentGoalID: parent.id)!
        let sibling = s.addGoal(title: "Sibling", kind: .shortTerm, areaID: nil, parentGoalID: parent.id)!
        let siblingID = sibling.id
        try require(s.addGoal(title: "Unsupported depth", kind: .shortTerm, areaID: nil, parentGoalID: child.id) == nil, "Short-term goal accepted as parent")
        try require(s.addGoal(title: "Invalid long child", kind: .longTerm, areaID: nil, parentGoalID: parent.id) == nil, "Long-term goal accepted a parent")
        let direct = s.addTask(title: "Direct", goalID: parent.id)!
        let nested = s.addTask(title: "Nested", goalID: child.id)!
        let parentID = parent.id, childID = child.id, directID = direct.id, nestedID = nested.id
        s.deleteGoal(parent); try s.refresh()
        try require(!s.goals.contains { $0.id == parentID }, "Deleted goal remains")
        try require(s.goals.contains { $0.id == childID && $0.parentGoalID == nil }, "Child not preserved and detached")
        try require(s.goals.contains { $0.id == siblingID && $0.parentGoalID == nil }, "Second child not preserved and detached")
        try require(s.tasks.contains { $0.id == directID && $0.goalID == nil }, "Direct task not preserved and detached")
        try require(s.tasks.contains { $0.id == nestedID && $0.goalID == childID }, "Nested task lost its goal")
    }

    static func recurrenceIsIdempotent() throws {
        for rule: RepeatRule in [.daily, .weekly] {
            let s = try store(), c = Calendar.current
            let start = c.date(byAdding: .day, value: 2, to: Date())!
            let task = s.addTask(title: "Repeat", scheduledDate: start, dueDate: start)!
            task.repeatRule = rule; s.save()
            s.toggleTask(task)
            let next = s.tasks.filter { $0.id != task.id }
            try require(next.count == 1, "Completion must create one successor")
            let successorID = next[0].id
            let expected = c.date(byAdding: .day, value: rule == .daily ? 1 : 7, to: start)!
            try require(next[0].scheduledDate.map { c.isDate($0, inSameDayAs: expected) } == true, "Wrong recurrence schedule")
            try require(!next[0].isCompleted && next[0].repeatRule == rule, "Successor state not copied correctly")
            s.toggleTask(task); s.toggleTask(task); try s.refresh()
            try require(s.tasks.filter { $0.id != task.id }.map(\.id) == [successorID], "Undo/redo duplicated recurrence")
        }
    }

    static func recurrenceSkipsMissedIntervals() throws {
        let s = try store(), c = Calendar.current
        let old = c.date(byAdding: .day, value: -20, to: Date())!
        let task = s.addTask(title: "Old recurring", scheduledDate: old)!
        task.repeatRule = .weekly; s.save(); s.toggleTask(task)
        let next = s.tasks.first { $0.id != task.id }
        try require(next != nil, "Missing successor for old recurring task")
        try require(next!.scheduledDate! >= c.startOfDay(for: Date()), "Missed repeat instances were not skipped")
        let days = c.dateComponents([.day], from: c.startOfDay(for: old), to: c.startOfDay(for: next!.scheduledDate!)).day!
        try require(days % 7 == 0, "Weekly phase lost while skipping missed intervals")
    }

    static func backupRoundTrip() throws {
        let s = try store()
        let areaID = s.areas.first!.id
        let goal = s.addGoal(title: "Outcome", kind: .longTerm, areaID: areaID)!
        goal.notes = "中文笔记"; goal.progress = 0.42
        let task = s.addTask(title: "Action", areaID: areaID, scheduledDate: date(2026, 10, 25), dueDate: date(2026, 10, 28), goalID: goal.id)!
        task.notes = "保留换行\n第二行"; task.priority = .high; task.repeatRule = .weekly
        s.save()
        let goalID = goal.id, taskID = task.id, data = try s.exportBackup()
        _ = s.addTask(title: "Must disappear")
        try s.restoreBackup(data)
        try require(s.tasks.count == 1 && s.goals.count == 1, "Backup did not replace current contents")
        let restored = s.tasks.first!
        try require(restored.id == taskID && restored.goalID == goalID && restored.areaID == areaID, "Backup changed stable IDs or links")
        try require(restored.notes == "保留换行\n第二行" && restored.priority == .high && restored.repeatRule == .weekly, "Backup lost task fields")
        try require(s.goals.first?.progress == 0.42 && s.goals.first?.notes == "中文笔记", "Backup lost goal progress or notes")
        try require(s.errorMessage == nil, "Store reported a save error during restore")
    }

    static func recurrenceDedupSurvivesBackupRestore() throws {
        let s = try store()
        let task = s.addTask(title: "Persistent repeat", scheduledDate: Date())!
        task.repeatRule = .daily; s.save(); s.toggleTask(task)
        let originalID = task.id, ids = Set(s.tasks.map(\.id))
        try s.restoreBackup(s.exportBackup())
        let restored = s.tasks.first { $0.id == originalID }!
        s.toggleTask(restored); s.toggleTask(restored)
        try require(Set(s.tasks.map(\.id)) == ids, "Backup restore lost recurrence deduplication state")
    }

    static func invalidGoalBackupsAreAtomic() throws {
        let s = try store()
        let parent = s.addGoal(title: "Parent", kind: .longTerm, areaID: nil)!
        let child = s.addGoal(title: "Child", kind: .shortTerm, areaID: nil, parentGoalID: parent.id)!
        let ids = Set(s.goals.map(\.id)), original = try s.exportBackup()
        var invalid: [Data] = []
        var object = try JSONSerialization.jsonObject(with: original) as! [String: Any]
        var goals = object["goals"] as! [[String: Any]]
        goals[0]["progress"] = 1.5; object["goals"] = goals
        invalid.append(try JSONSerialization.data(withJSONObject: object))
        object = try JSONSerialization.jsonObject(with: original) as! [String: Any]
        goals = object["goals"] as! [[String: Any]]
        let parentIndex = goals.firstIndex { ($0["id"] as? String)?.lowercased() == parent.id.uuidString.lowercased() }!
        goals[parentIndex]["parentGoalID"] = child.id.uuidString; object["goals"] = goals
        invalid.append(try JSONSerialization.data(withJSONObject: object))
        for data in invalid {
            var rejected = false
            do { try s.restoreBackup(data) } catch { rejected = true }
            try require(rejected, "Out-of-range progress or cyclic goal hierarchy accepted")
            try s.refresh()
            try require(Set(s.goals.map(\.id)) == ids && s.goals.allSatisfy { $0.progress == 0 }, "Invalid goal backup damaged existing goals")
        }
    }

    static func rejectedBackupLeavesStoreIntact() throws {
        let s = try store()
        let task = s.addTask(title: "Keep me")!
        let id = task.id
        let original = try s.exportBackup()
        var object = try JSONSerialization.jsonObject(with: original) as! [String: Any]
        var invalid: [Data] = [Data("not json".utf8), Data("{}".utf8)]
        object["schemaVersion"] = 999
        invalid.append(try JSONSerialization.data(withJSONObject: object))
        object = try JSONSerialization.jsonObject(with: original) as! [String: Any]
        var records = object["tasks"] as! [[String: Any]]
        records.append(records[0]); object["tasks"] = records
        invalid.append(try JSONSerialization.data(withJSONObject: object))
        object = try JSONSerialization.jsonObject(with: original) as! [String: Any]
        records = object["tasks"] as! [[String: Any]]
        records[0]["goalID"] = UUID().uuidString; object["tasks"] = records
        invalid.append(try JSONSerialization.data(withJSONObject: object))
        for data in invalid {
            var rejected = false
            do { try s.restoreBackup(data) } catch { rejected = true }
            try require(rejected, "Malformed, incompatible, duplicate, or dangling-link backup accepted")
            try s.refresh()
            try require(s.tasks.count == 1 && s.tasks.first?.id == id && s.tasks.first?.title == "Keep me", "Rejected backup damaged existing data")
        }
    }

    static func invalidImportPreservesPendingEdits() throws {
        let s = try store()
        let task = s.addTask(title: "Saved title")!
        task.title = "Pending direct edit"
        var rejected = false
        do { try s.restoreBackup(Data("{}".utf8)) } catch { rejected = true }
        try require(rejected, "Invalid import accepted")
        try require(task.title == "Pending direct edit" && s.tasks.first?.title == "Pending direct edit", "Rejected import discarded pending edits")
        s.save()
        try require(s.errorMessage == nil, "Pending edit could not be saved after import rejection")
        let goalCount = s.goals.count
        try require(s.addGoal(title: "Invalid new goal", kind: .longTerm, areaID: nil, progress: 2) == nil, "Invalid new goal accepted")
        try require(s.goals.count == goalCount, "Failed atomic creation left a partial goal")
    }

    static func observedModelsAndRollback() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("Dayline-Observation-QA-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("observation.store")
        try seedPersistentStore(url)
        let s = try DaylineStore(container: DaylineStore.makeContainer(url: url))
        let task = s.tasks[0], goal = s.goals[0], area = s.areas[0]
        let taskProbe = ObservationProbe(), goalProbe = ObservationProbe(), areaProbe = ObservationProbe()
        withObservationTracking { _ = task.title } onChange: { taskProbe.signal() }
        withObservationTracking { _ = goal.progress } onChange: { goalProbe.signal() }
        withObservationTracking { _ = area.symbol } onChange: { areaProbe.signal() }
        task.title = "Observed edit"; goal.progress = 0.8; area.symbol = "book"
        try require(taskProbe.changes == 1 && goalProbe.changes == 1 && areaProbe.changes == 1, "Persisted model edits did not notify observers")
        s.save()
        try require(s.errorMessage == nil, "Observed model edit failed to save")
        goal.progress = 2
        s.save()
        try require(s.errorMessage != nil, "Invalid goal progress did not report save failure")
        try require(s.goals[0].progress == 0.8, "Rollback did not restore last saved goal progress")
        try require(s.tasks[0].title == "Observed edit", "Rollback damaged previously saved task")
        let afterRollback = ObservationProbe()
        withObservationTracking { _ = s.goals[0].progress } onChange: { afterRollback.signal() }
        s.goals[0].progress = 0.9
        try require(afterRollback.changes == 1, "Rollback broke subsequent observation")
        s.save()
        try require(s.errorMessage == nil, "Valid save after rollback failed")
    }

    static func persistenceSurvivesReopen() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("Dayline-QA-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("test.store")
        try seedPersistentStore(url)
        try inspectPersistentStore(url)
    }

    static func seedPersistentStore(_ url: URL) throws {
        let s = try DaylineStore(container: DaylineStore.makeContainer(url: url))
        let goal = s.addGoal(title: "Persistent goal", kind: .longTerm, areaID: s.areas.first?.id)!
        goal.progress = 0.73
        let task = s.addTask(title: "Persistent task", scheduledDate: date(2026, 10, 25), goalID: goal.id)!
        task.notes = "磁盘重启验证"; task.priority = .high
        s.save()
        try require(s.errorMessage == nil, "Persisting fixture reported error")
    }

    static func inspectPersistentStore(_ url: URL) throws {
        let s = try DaylineStore(container: DaylineStore.makeContainer(url: url))
        try require(s.tasks.count == 1 && s.tasks[0].title == "Persistent task", "Disk reopen lost task")
        try require(s.goals.count == 1 && s.goals[0].progress == 0.73, "Disk reopen lost goal")
        try require(s.tasks[0].goalID == s.goals[0].id && s.tasks[0].notes == "磁盘重启验证" && s.tasks[0].priority == .high, "Disk reopen lost fields or linkage")
        try require(s.areas.count == 3, "Reopen duplicated or lost default areas")
    }

    static func demoIsExplicitAndIdempotent() throws {
        let s = try store()
        try require(s.tasks.isEmpty && s.goals.isEmpty, "Fresh store silently populated demo data")
        s.loadDemoData()
        let taskIDs = Set(s.tasks.map(\.id)), goalIDs = Set(s.goals.map(\.id))
        try require(!taskIDs.isEmpty && !goalIDs.isEmpty, "Demo did not load")
        s.loadDemoData()
        try require(Set(s.tasks.map(\.id)) == taskIDs && Set(s.goals.map(\.id)) == goalIDs, "Repeated demo import duplicated content")
    }

    static var all: [(String, () throws -> Void)] { [
        ("Today scheduled OR due, once", todayUsesEitherDateOnce),
        ("Overdue and explicit carryover", overdueAndCarryoverAreDistinct),
        ("DST and calendar boundaries", dstAndCalendarBoundaries),
        ("Inbox retains due-only tasks", inboxKeepsDueOnlyTasks),
        ("Blank titles rejected and trimmed", rejectsBlankAndTrimsTitles),
        ("Goal deletion preserves descendants and tasks", goalDeletionPreservesDescendantsAndTasks),
        ("Recurrence undo/redo deduplication", recurrenceIsIdempotent),
        ("Recurrence skips missed intervals", recurrenceSkipsMissedIntervals),
        ("Backup field and identity round trip", backupRoundTrip),
        ("Invalid backups leave data intact", rejectedBackupLeavesStoreIntact),
        ("Invalid goal progress and cycles are atomic", invalidGoalBackupsAreAtomic),
        ("Recurrence dedup survives backup restore", recurrenceDedupSurvivesBackupRestore),
        ("Invalid import preserves pending edits and atomic creation", invalidImportPreservesPendingEdits),
        ("Observed disk models and validation rollback", observedModelsAndRollback),
        ("Temporary disk store reopen", persistenceSurvivesReopen),
        ("Demo is explicit and idempotent", demoIsExplicitAndIdempotent)
    ] }
}
