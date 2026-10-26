import Foundation
import DaylineCore
import SwiftData
import Observation
import SQLite3
import Darwin
#if canImport(Dayline)
@testable import Dayline
#endif

@MainActor
enum V11Checks {
    private static func fixture(_ name: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures", isDirectory: true)
            .appendingPathComponent(name)
    }
    private static func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        try RuleChecks.require(condition(), message)
    }
    private static func unwrap<T>(_ value: T?, _ message: String) throws -> T {
        guard let value else { throw CheckFailure(description: message) }
        return value
    }
    private static func backup(_ store: DaylineStore) throws -> DaylineBackup {
        try DaylineBackup.decoder().decode(DaylineBackup.self, from: store.exportBackup())
    }
    private static func localDay(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current; formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    static func ideaCRUDAndObservation() throws {
        let s = try RuleChecks.store()
        let idea = try unwrap(s.addIdea(title: "", body: ""), "Empty writing draft was rejected")
        let id = idea.id, created = idea.createdAt
        let titleProbe = ObservationProbe(), bodyProbe = ObservationProbe(), archiveProbe = ObservationProbe()
        withObservationTracking { _ = idea.title } onChange: { titleProbe.signal() }
        withObservationTracking { _ = idea.body } onChange: { bodyProbe.signal() }
        withObservationTracking { _ = idea.isArchived } onChange: { archiveProbe.signal() }
        s.updateIdea(idea, title: "想法 🪴", body: "第一行\n第二行\n最后一次输入", areaID: nil, goalID: nil)
        s.setIdeaPinned(idea, to: true); s.setIdeaArchived(idea, to: true)
        try require(titleProbe.changes == 1 && bodyProbe.changes == 1 && archiveProbe.changes == 1,
                    "Idea changes did not notify observed UI properties")
        try s.refresh()
        let stored = try unwrap(s.ideas.first, "Idea disappeared after refresh")
        try require(stored.id == id && stored.createdAt == created && stored.updatedAt >= created, "Idea identity/dates changed")
        try require(stored.title == "想法 🪴" && stored.body.hasSuffix("最后一次输入"), "Immediate edits were not committed")
        try require(stored.isPinned && stored.isArchived, "Pin/archive state not saved")
        s.setIdeaPinned(stored, to: false); s.setIdeaArchived(stored, to: false)
        try require(!stored.isPinned && !stored.isArchived, "Pin/archive toggles could not be undone")
        try require(s.tasks.isEmpty && s.planningEvents.isEmpty, "Ideas changed task completion/history counts")
        s.deleteIdea(stored)
        try require(s.ideas.isEmpty && s.errorMessage == nil, "Idea deletion failed")
    }

    static func conversionAndGoalNullification() throws {
        let s = try RuleChecks.store(), area = s.areas[0].id
        let goal = try unwrap(s.addGoal(title: "成果", kind: .longTerm, areaID: area, progress: 0.4), "Goal setup failed")
        let idea = try unwrap(s.addIdea(title: "  灵感标题  ", body: "中文\n完整笔记 🌱", areaID: area, goalID: goal.id), "Idea setup failed")
        let id = idea.id, date = idea.updatedAt
        s.setIdeaPinned(idea, to: true); s.setIdeaArchived(idea, to: true)
        let completed = s.tasks.filter(\.isCompleted).count
        let task = try unwrap(s.taskFromIdea(idea), "Conversion failed")
        try require(task.title == "灵感标题" && task.notes == idea.body && task.areaID == area && task.goalID == goal.id, "Conversion lost text/links")
        try require(task.scheduledDate == nil && task.dueDate == nil && !task.isCompleted && task.completedAt == nil, "Conversion scheduled or completed task")
        try require(s.ideas.count == 1 && idea.id == id && idea.title == "  灵感标题  " && idea.isPinned && idea.isArchived && idea.updatedAt >= date, "Conversion modified the source idea")
        try require(s.tasks.filter(\.isCompleted).count == completed && goal.progress == 0.4, "Conversion changed completion count or goal progress")
        try require(!s.planningEvents.contains { $0.kind == .completed }, "Conversion invented completion history")
        s.deleteGoal(goal)
        try require(s.ideas.first?.goalID == nil && s.ideas.first?.areaID == area && task.goalID == nil,
                    "Deleting goal did not nullify Idea and task links while retaining area")
        s.updateIdea(idea, title: "", body: idea.body, areaID: area, goalID: nil)
        let unnamed = try unwrap(s.taskFromIdea(idea), "Empty-title idea conversion failed")
        try require(unnamed.title == "未命名灵感" && s.ideas.count == 1, "Empty-title conversion fallback or source retention failed")
        s.deleteIdea(idea)
        try require(s.tasks.count == 2, "Deleting source idea also deleted converted tasks")
    }

    static func invalidIdeaMutationsRollback() throws {
        let s = try RuleChecks.store()
        let idea = try unwrap(s.addIdea(title: "保留", body: "已保存正文"), "Idea setup failed")
        let id = idea.id
        try require(s.addIdea(title: "坏关联", goalID: UUID()) == nil, "Dangling goal creation succeeded")
        try require(s.ideas.count == 1 && s.ideas[0].id == id, "Failed add left partial idea")
        s.updateIdea(idea, title: "不应保存", body: "损坏", areaID: nil, goalID: UUID())
        try require(s.errorMessage != nil && s.ideas[0].title == "保留" && s.ideas[0].body == "已保存正文", "Invalid edit was not rolled back")
        s.ideas[0].updatedAt = Date(timeIntervalSince1970: 400_000_000_000)
        s.save()
        try require(s.errorMessage != nil && s.ideas[0].updatedAt.timeIntervalSince1970 < 253_402_300_800, "Invalid Idea date was committed")
        s.updateIdea(s.ideas[0], title: "继续写", body: "恢复后输入", areaID: nil, goalID: nil)
        try require(s.errorMessage == nil && s.ideas[0].body == "恢复后输入", "Valid edit after rollback failed")
    }

    static func directTaskEditsCaptureHistory() throws {
        let s = try RuleChecks.store()
        let first = Calendar.current.startOfDay(for: Date())
        let second = Calendar.current.date(byAdding: .day, value: 1, to: first)!
        let third = Calendar.current.date(byAdding: .day, value: 2, to: first)!
        let task = try unwrap(s.addTask(title: "历史", scheduledDate: first, dueDate: third), "Task setup failed")
        let id = task.id
        try require(s.planningEvents.map(\.kind) == [.planned] && s.planningEvents[0].dayKey == localDay(first), "Creation uses wrong event/date precedence")
        task.title = "编辑后的历史"; task.notes = "不会增加历史事件"; s.save()
        try require(s.planningEvents.count == 1, "Text-only edits polluted planning history")
        task.scheduledDate = second; s.save()
        let rescheduled = try unwrap(s.planningEvents.last, "Missing reschedule event")
        try require(rescheduled.kind == .rescheduled && rescheduled.dayKey == localDay(first) && rescheduled.newDayKey == localDay(second), "Direct date edit failed to capture old/new plan days")
        task.isCompleted = true; task.completedAt = Date(); s.save()
        task.isCompleted = false; task.completedAt = nil; s.save()
        s.reschedule(task, to: nil) // Due-date fallback becomes the assigned day.
        s.deleteTask(task)
        let events = s.planningEvents.filter { $0.taskID == id }
        try require(events.map(\.kind) == [.planned, .rescheduled, .completed, .reopened, .rescheduled, .deleted], "Event capture/order differs after edit, completion undo, reschedule and deletion")
        try require(events[2].wasCompleted && !events[3].wasCompleted && events[4].newDayKey == localDay(third) && events[5].dayKey == localDay(third), "Event snapshots or due-date fallback incorrect")
        let ids = events.map(\.id)
        try s.refresh(); s.save()
        try require(s.planningEvents.map(\.id) == ids && s.tasks.isEmpty, "Refresh/no-op save duplicated or reordered history")
    }

    static func planningAssignmentsSurviveTimeZoneChanges() throws {
        let previousEnvironment = getenv("TZ").map { String(cString: $0) }
        let previousDefault = NSTimeZone.default
        defer {
            if let previousEnvironment { setenv("TZ", previousEnvironment, 1) } else { unsetenv("TZ") }
            tzset(); NSTimeZone.resetSystemTimeZone(); NSTimeZone.default = previousDefault
        }
        func setZone(_ name: String) throws {
            setenv("TZ", name, 1); tzset(); NSTimeZone.resetSystemTimeZone()
            NSTimeZone.default = TimeZone(identifier: name)!
            try require(TimeZone.current.identifier == name && Calendar.current.timeZone.identifier == name,
                        "Timezone fixture did not change actual current Foundation calendar/timezone")
        }
        try setZone("Asia/Shanghai")
        let shanghaiMidnight = RuleChecks.date(2026, 10, 25, 0, 0, calendar: RuleChecks.calendar("Asia/Shanghai"))
        try require(localDay(shanghaiMidnight) == "2026-10-25", "Shanghai fixed instant has wrong day")
        let s = try RuleChecks.store()
        let completion = try unwrap(s.addTask(title: "跨区完成", scheduledDate: shanghaiMidnight), "Completion fixture failed")
        let deletion = try unwrap(s.addTask(title: "跨区截止删除", dueDate: shanghaiMidnight), "Due fixture failed")
        let moving = try unwrap(s.addTask(title: "跨区改期", scheduledDate: shanghaiMidnight), "Reschedule fixture failed")
        let clearing = try unwrap(s.addTask(title: "取消安排", scheduledDate: shanghaiMidnight), "Clearing fixture failed")
        let baseline = try unwrap(s.addTask(title: "已有基线", scheduledDate: shanghaiMidnight), "Baseline fixture failed")
        let unscheduled = try unwrap(s.addTask(title: "未安排"), "Unscheduled fixture failed")
        var document = try backup(s)
        let capturedAt = RuleChecks.date(2026, 10, 24, 12, 0, calendar: RuleChecks.calendar("Asia/Shanghai"))
        for index in document.planningEvents.indices {
            document.planningEvents[index].occurredAt = capturedAt.addingTimeInterval(Double(index))
            if document.planningEvents[index].taskID == baseline.id { document.planningEvents[index].kind = .baseline }
        }
        try s.restoreBackup(DaylineBackup.encoder().encode(document))
        let originalIDs = s.planningEvents.map(\.id)
        try setZone("America/Los_Angeles")
        try require(localDay(shanghaiMidnight) == "2026-10-24", "Fixed timestamp must cross calendar day in Los Angeles")
        s.save()
        try require(s.planningEvents.map(\.id) == originalIDs, "Timezone change alone invented reschedules")

        let beforeActions = Date()
        s.toggleTask(completion); s.toggleTask(completion)
        s.deleteTask(deletion)
        s.toggleTask(baseline)
        s.toggleTask(unscheduled)
        s.reschedule(clearing, to: nil); s.toggleTask(clearing)
        let losAngelesLate = RuleChecks.date(2026, 10, 26, 23, 30, calendar: RuleChecks.calendar("America/Los_Angeles"))
        moving.scheduledDate = losAngelesLate
        moving.isCompleted = true; moving.completedAt = Date()
        s.save() // A combined date/completion edit must use the newly assigned day for completion.
        let events = s.planningEvents
        let completionEvents = events.filter { $0.taskID == completion.id && $0.kind != .planned }
        try require(completionEvents.map(\.kind) == [.completed, .reopened] && completionEvents.allSatisfy { $0.dayKey == "2026-10-25" },
                    "Completion/reopening moved the original Shanghai plan into the Los Angeles day")
        try require(events.last { $0.taskID == deletion.id }?.dayKey == "2026-10-25", "Deletion closed wrong plan day after travel")
        try require(events.last { $0.taskID == baseline.id }?.dayKey == "2026-10-25", "Baseline assignment was reinterpreted after travel")
        try require(events.last { $0.taskID == unscheduled.id }?.dayKey == nil, "Unscheduled planned event gained a day")
        let clearingEvents = events.filter { $0.taskID == clearing.id && $0.kind != .planned }
        try require(clearingEvents.count == 2 && clearingEvents[0].kind == .rescheduled && clearingEvents[0].dayKey == "2026-10-25"
                    && clearingEvents[0].newDayKey == nil && clearingEvents[1].dayKey == nil,
                    "Clearing a plan lost the original assignment or reintroduced its old day")
        let movingEvents = events.filter { $0.taskID == moving.id && $0.kind != .planned }
        try require(movingEvents.count == 2 && movingEvents[0].kind == .rescheduled && movingEvents[0].dayKey == "2026-10-25"
                    && movingEvents[0].newDayKey == "2026-10-26" && movingEvents[1].kind == .completed && movingEvents[1].dayKey == "2026-10-26",
                    "Reschedule old/new association or same-save completion assignment is wrong")
        try require(events.dropFirst(originalIDs.count).allSatisfy { $0.timeZoneID == "America/Los_Angeles" && $0.occurredAt >= beforeActions && $0.occurredAt <= Date() },
                    "Action timestamp/timezone did not retain actual local capture context")
        try require(Array(events.prefix(originalIDs.count)).map(\.id) == originalIDs, "Travel replaced historical IDs")

        // Returning home must keep the newly assigned Los Angeles day, not reinterpret its timestamp.
        try setZone("Asia/Shanghai")
        try require(localDay(losAngelesLate) == "2026-10-27", "Return-trip fixture must cross a day boundary")
        s.toggleTask(moving); s.deleteTask(moving)
        let returned = Array(s.planningEvents.suffix(2))
        try require(returned.map(\.kind) == [.reopened, .deleted] && returned.allSatisfy { $0.dayKey == "2026-10-26" && $0.timeZoneID == "Asia/Shanghai" },
                    "Replayed reschedule assignment changed after returning to Shanghai")
        let newTask = try unwrap(s.addTask(title: "新安排使用当前时区", scheduledDate: losAngelesLate), "New local plan failed")
        try require(s.planningEvents.last { $0.taskID == newTask.id }?.dayKey == "2026-10-27", "New plans did not use the current local day")
        try require(s.errorMessage == nil, "Cross-zone history save failed")
    }

    static func v2RoundTripAndEqualTimeOrder() throws {
        let s = try RuleChecks.store(), area = s.areas[1].id
        let goal = try unwrap(s.addGoal(title: "研究", kind: .longTerm, areaID: area), "Goal setup failed")
        let idea = try unwrap(s.addIdea(title: "", body: String(repeating: "长文本中文 🧠\n", count: 300), areaID: area, goalID: goal.id), "Idea setup failed")
        s.setIdeaPinned(idea, to: true); s.setIdeaArchived(idea, to: true)
        let task = try unwrap(s.taskFromIdea(idea), "Conversion failed")
        s.toggleTask(task); s.toggleTask(task); s.toggleTask(task)
        var document = try backup(s)
        let sameTime = Date(timeIntervalSince1970: 1_792_872_000)
        for index in document.planningEvents.indices { document.planningEvents[index].occurredAt = sameTime }
        let eventIDs = document.planningEvents.map(\.id)
        let destination = try RuleChecks.store()
        try destination.restoreBackup(DaylineBackup.encoder().encode(document))
        let restored = try unwrap(destination.ideas.first, "V2 restore lost Idea")
        try require(restored.id == idea.id && restored.title.isEmpty && restored.body == idea.body && restored.isPinned && restored.isArchived,
                    "V2 restore lost Idea fields")
        try require(restored.areaID == area && restored.goalID == goal.id && abs(restored.createdAt.timeIntervalSince(idea.createdAt)) < 0.001,
                    "V2 restore changed Idea date or links")
        try require(destination.planningEvents.map(\.id) == eventIDs, "Equal-time event insertion order lost in restore")
        let exported = try backup(destination)
        try require(exported.schemaVersion == 2 && exported.planningEvents.map(\.id) == eventIDs && exported.planningEvents.map(\.kind) == [.planned, .completed, .reopened, .completed], "V2 export lost historical identity/order")
        try destination.restoreBackup(destination.exportBackup())
        try require(destination.planningEvents.map(\.id) == eventIDs && destination.tasks[0].isCompleted, "Second round trip duplicated baselines or lost completion")
    }

    static func genuineV1Restoration() throws {
        let url = fixture("v1-backup.json")
        let data = try Data(contentsOf: url)
        let object = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        try require(object["schemaVersion"] as? Int == 1 && object["ideas"] == nil && object["planningEvents"] == nil, "Fixture must be genuine v1 JSON")
        let document = try DaylineBackup.decoder().decode(DaylineBackup.self, from: data)
        let s = try RuleChecks.store()
        _ = s.addIdea(title: "替换前")
        let before = Date()
        try s.restoreBackup(data)
        try require(s.ideas.isEmpty && Set(s.tasks.map(\.id)) == Set(document.tasks.map(\.id)) && Set(s.goals.map(\.id)) == Set(document.goals.map(\.id)), "V1 restoration changed IDs or retained replaced ideas")
        for original in document.tasks {
            let task = try unwrap(s.tasks.first { $0.id == original.id }, "Missing v1 task")
            try require(task.title == original.title && task.notes == original.notes && task.goalID == original.goalID && task.areaID == original.areaID && task.isCompleted == original.isCompleted && task.recurrenceSourceID == original.recurrenceSourceID && task.recurrenceSuccessorID == original.recurrenceSuccessorID,
                        "V1 restoration changed task fields/recurrence identity")
        }
        try require(s.planningEvents.count == document.tasks.count && s.planningEvents.allSatisfy { $0.kind == .baseline && $0.occurredAt >= before }, "V1 import fabricated earlier history")
        let baselineIDs = Set(s.planningEvents.map(\.id))
        try s.restoreBackup(s.exportBackup())
        try require(Set(s.planningEvents.map(\.id)) == baselineIDs, "V1 migration baselines changed in v2 round trip")
    }

    static func invalidV2ImportsAreAtomic() throws {
        let s = try RuleChecks.store()
        let idea = try unwrap(s.addIdea(title: "保存我的灵感", body: "不要丢失"), "Idea setup failed")
        _ = s.addTask(title: "保留任务", scheduledDate: Date())
        let original = try backup(s), id = idea.id
        let taskIDs = Set(s.tasks.map(\.id)), eventIDs = s.planningEvents.map(\.id)
        var variants: [(String, DaylineBackup)] = []
        var bad = original; bad.ideas[0].goalID = UUID(); variants.append(("dangling Idea goal", bad))
        bad = original; bad.ideas[0].areaID = UUID(); variants.append(("dangling Idea area", bad))
        bad = original; bad.ideas[0].createdAt = Date(timeIntervalSince1970: -70_000_000_000); variants.append(("Idea date range", bad))
        bad = original; bad.ideas.append(bad.ideas[0]); variants.append(("duplicate Idea ID", bad))
        bad = original; bad.planningEvents[0].timeZoneID = "Invalid/Zone"; variants.append(("event timezone", bad))
        bad = original; bad.planningEvents[0].dayKey = "2026-02-30"; variants.append(("event day", bad))
        bad = original; bad.planningEvents[0].newDayKey = "2026-1-01"; variants.append(("event new day", bad))
        bad = original; bad.planningEvents[0].occurredAt = Date(timeIntervalSince1970: 400_000_000_000); variants.append(("event date", bad))
        bad = original; bad.planningEvents[0].occurrenceDate = Date(timeIntervalSince1970: 400_000_000_000); variants.append(("event occurrence", bad))
        bad = original; bad.planningEvents.append(bad.planningEvents[0]); variants.append(("duplicate event ID", bad))
        for (name, document) in variants {
            var rejected = false
            do { try s.restoreBackup(DaylineBackup.encoder().encode(document)) } catch { rejected = true }
            try require(rejected, "Accepted invalid \(name)")
            try s.refresh()
            try require(s.ideas.count == 1 && s.ideas[0].id == id && s.ideas[0].body == "不要丢失" && Set(s.tasks.map(\.id)) == taskIDs && s.planningEvents.map(\.id) == eventIDs,
                        "Rejected \(name) mutated saved data/history")
        }
        var object = try JSONSerialization.jsonObject(with: DaylineBackup.encoder().encode(original)) as! [String: Any]
        var records = object["planningEvents"] as! [[String: Any]]
        records[0]["kind"] = "madeUpEvent"; object["planningEvents"] = records
        s.ideas[0].body = "尚未保存的输入"
        var rejected = false
        do { try s.restoreBackup(JSONSerialization.data(withJSONObject: object)) } catch { rejected = true }
        try require(rejected && s.ideas[0].body == "尚未保存的输入", "Invalid event enum discarded pending Idea text")
        s.save()
        try require(s.errorMessage == nil, "Pending Idea edit could not be saved after failed import")
    }

    static func recurringMigrationKeepsBaselines() throws {
        let source = try RuleChecks.store()
        let task = try unwrap(source.addTask(title: "重复", scheduledDate: Date(), repeatRule: .daily), "Repeat setup failed")
        source.toggleTask(task)
        var old = try backup(source)
        old.schemaVersion = 1; old.ideas = []; old.planningEvents = []
        let s = try RuleChecks.store()
        try s.restoreBackup(DaylineBackup.encoder().encode(old))
        let taskIDs = Set(s.tasks.map(\.id)), baselineIDs = Set(s.planningEvents.map(\.id))
        let root = try unwrap(s.tasks.first { $0.id == task.id }, "Original recurring task missing")
        let successor = root.recurrenceSuccessorID
        s.toggleTask(root); s.toggleTask(root)
        try require(Set(s.tasks.map(\.id)) == taskIDs && root.recurrenceSuccessorID == successor, "Migrated repeat undo/redo duplicated occurrence")
        try require(Set(s.planningEvents.filter { $0.kind == .baseline }.map(\.id)) == baselineIDs, "Repeat completion changed baseline IDs")
        try require(s.planningEvents.filter { $0.kind == .completed }.allSatisfy { $0.recurrenceSourceID == root.id && $0.occurrenceDate == root.recurrenceOccurrenceDate }, "Repeat event lost stable series/occurrence identity")
        try s.restoreBackup(s.exportBackup())
        try require(Set(s.planningEvents.filter { $0.kind == .baseline }.map(\.id)) == baselineIDs && Set(s.tasks.map(\.id)) == taskIDs, "Backup restore regenerated baselines/repeat occurrences")
    }

    static func seedDisk(_ url: URL) throws {
        let s = try DaylineStore(container: DaylineStore.makeContainer(url: url))
        let goal = try unwrap(s.addGoal(title: "磁盘目标", kind: .longTerm, areaID: s.areas[0].id), "Disk goal setup failed")
        let idea = try unwrap(s.addIdea(title: "磁盘灵感", body: "初始", areaID: goal.areaID, goalID: goal.id), "Disk idea setup failed")
        s.setIdeaPinned(idea, to: true); s.setIdeaArchived(idea, to: true)
        let task = try unwrap(s.taskFromIdea(idea), "Disk conversion failed")
        s.toggleTask(task); s.toggleTask(task)
        let snapshot = try backup(s)
        let manifest: [String: Any] = ["idea": idea.id.uuidString, "goal": goal.id.uuidString,
                                      "events": snapshot.planningEvents.map { $0.id.uuidString }]
        try JSONSerialization.data(withJSONObject: manifest).write(to: url.appendingPathExtension("manifest"))
        // Last operation before the child exits. No explicit save, refresh, sleep, or autosave run loop.
        s.updateIdea(idea, title: "最后标题 🌱", body: "第一行\n退出前的最后输入", areaID: idea.areaID, goalID: idea.goalID)
    }

    static func inspectDisk(_ url: URL) throws {
        let manifest = try JSONSerialization.jsonObject(with: Data(contentsOf: url.appendingPathExtension("manifest"))) as! [String: Any]
        let s = try DaylineStore(container: DaylineStore.makeContainer(url: url))
        let idea = try unwrap(s.ideas.first, "Separate-process reopen lost Idea")
        try require(s.ideas.count == 1 && idea.id.uuidString == manifest["idea"] as? String && idea.goalID?.uuidString == manifest["goal"] as? String,
                    "Separate-process reopen changed Idea IDs/links")
        try require(idea.title == "最后标题 🌱" && idea.body == "第一行\n退出前的最后输入" && idea.isPinned && idea.isArchived,
                    "Immediate final edit/pin/archive failed to persist before quit")
        try require(s.planningEvents.map { $0.id.uuidString } == manifest["events"] as? [String] && s.planningEvents.map(\.kind) == [.planned, .completed, .reopened], "Reopen duplicated or reordered events")
        let probe = ObservationProbe()
        withObservationTracking { _ = idea.body } onChange: { probe.signal() }
        s.updateIdea(idea, title: idea.title, body: "重新打开后继续", areaID: idea.areaID, goalID: idea.goalID)
        try require(probe.changes == 1 && s.errorMessage == nil, "Reopened Idea lost Observation/save behavior")
    }

    static func legacySQLiteMigration() throws {
        let source = fixture("v1.store")
        let originalIDs = try sqliteStrings(source, query: "SELECT hex(ZID) FROM ZDAYTASK ORDER BY hex(ZID)")
        let sourceIdeaTables = try sqliteStrings(source, query: "SELECT name FROM sqlite_master WHERE name='ZIDEA'")
        try require(!originalIDs.isEmpty && sourceIdeaTables.isEmpty,
                    "Migration fixture must be a genuine populated v1 SQLite schema")
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("Dayline-v11-Migration-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let copy = directory.appendingPathComponent("migrated.store")
        try sqliteBackup(from: source, to: copy)
        let before = Date()
        let s = try DaylineStore(container: DaylineStore.makeContainer(url: copy))
        try RuleChecks.inspectPersistentStore(copy)
        let migratedIDs = s.tasks.map { $0.id.uuidString.replacingOccurrences(of: "-", with: "") }.sorted()
        try require(migratedIDs == originalIDs && s.ideas.isEmpty, "Migration lost v1 task IDs or fabricated Ideas")
        try require(s.planningEvents.count == s.tasks.count && s.planningEvents.allSatisfy { $0.kind == .baseline && $0.occurredAt >= before }, "SQLite upgrade invented pre-upgrade history")
        let baselineIDs = Set(s.planningEvents.map(\.id))
        let idea = try unwrap(s.addIdea(title: "升级后灵感", body: "可保存"), "Migrated store cannot add Idea")
        s.updateIdea(idea, title: "升级后编辑", body: "仍然可保存", areaID: nil, goalID: nil)
        try s.refresh()
        try require(s.ideas.first?.body == "仍然可保存" && Set(s.planningEvents.map(\.id)) == baselineIDs, "Post-migration write changed baseline identity")
        let afterSourceIdeaTables = try sqliteStrings(source, query: "SELECT name FROM sqlite_master WHERE name='ZIDEA'")
        try require(afterSourceIdeaTables.isEmpty,
                    "Migration test mutated the genuine source fixture")
    }

    static func safetySnapshotsHandleColdAndLiveWAL() throws {
        let source = fixture("v1.store")
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("Dayline-v11-Safety-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let ids = try sqliteStrings(source, query: "SELECT hex(ZID) FROM ZDAYTASK ORDER BY hex(ZID)")
        let cold = directory.appendingPathComponent("cold.store")
        try sqliteBackup(from: source, to: cold)
        try makeColdWALFixture(cold)
        let header = try Data(contentsOf: cold)
        try require(header[18] == 2 && header[19] == 2, "Cold fixture must retain genuine WAL-mode header")
        try require(!FileManager.default.fileExists(atPath: cold.path + "-wal") && !FileManager.default.fileExists(atPath: cold.path + "-shm"),
                    "Cold fixture unexpectedly has WAL sidecars")
        try DaylineSafetyBackup.beforeUpgrade(at: cold)
        let snapshot = URL(fileURLWithPath: cold.path + ".before-v1.1.sqlite")
        let savedIDs = try sqliteStrings(snapshot, query: "SELECT hex(ZID) FROM ZDAYTASK ORDER BY hex(ZID)")
        let mode = try sqliteStrings(snapshot, query: "PRAGMA journal_mode")
        try require(savedIDs == ids && mode == ["delete"], "Cold-store safety snapshot is not a complete standalone database")
        let savedData = try Data(contentsOf: snapshot)
        try DaylineSafetyBackup.beforeUpgrade(at: cold)
        let secondData = try Data(contentsOf: snapshot)
        try require(savedData == secondData, "Second upgrade check overwrote the original safety snapshot")

        let live = directory.appendingPathComponent("live.store")
        try sqliteBackup(from: source, to: live)
        var writer: OpaquePointer?
        guard sqlite3_open_v2(live.path, &writer, SQLITE_OPEN_READWRITE, nil) == SQLITE_OK else { throw CheckFailure(description: "Cannot open live WAL fixture") }
        defer { sqlite3_close(writer) }
        try require(sqlite3_exec(writer, "PRAGMA journal_mode=WAL; PRAGMA wal_autocheckpoint=0; UPDATE ZDAYTASK SET ZNOTES='WAL-only committed note'", nil, nil, nil) == SQLITE_OK,
                    "Cannot create committed WAL-only fixture edit")
        let walAttributes = try FileManager.default.attributesOfItem(atPath: live.path + "-wal")
        try require((walAttributes[.size] as? NSNumber)?.intValue ?? 0 > 0, "Live WAL fixture has no log data")
        try DaylineSafetyBackup.beforeUpgrade(at: live)
        let liveSnapshot = URL(fileURLWithPath: live.path + ".before-v1.1.sqlite")
        let notes = try sqliteStrings(liveSnapshot, query: "SELECT ZNOTES FROM ZDAYTASK")
        let liveMode = try sqliteStrings(liveSnapshot, query: "PRAGMA journal_mode")
        try require(notes == ["WAL-only committed note"] && liveMode == ["delete"], "Safety snapshot omitted committed WAL content or depends on sidecars")
        let originalNotes = try sqliteStrings(source, query: "SELECT ZNOTES FROM ZDAYTASK")
        try require(originalNotes == ["磁盘重启验证"], "Safety test mutated the genuine source fixture")
    }

    private static func makeColdWALFixture(_ copy: URL) throws {
        // The portable source fixture uses DELETE journaling. Set WAL only on the isolated
        // test copy, then close normally so SQLite removes its transient WAL/SHM sidecars.
        var writer: OpaquePointer?
        defer { if let writer { sqlite3_close(writer) } }
        try require(sqlite3_open_v2(copy.path, &writer, SQLITE_OPEN_READWRITE, nil) == SQLITE_OK,
                    "Cannot open isolated cold WAL fixture")
        try require(sqlite3_exec(writer, "PRAGMA journal_mode=WAL", nil, nil, nil) == SQLITE_OK,
                    "Cannot enable WAL on isolated cold fixture")
        try require(sqlite3_close(writer) == SQLITE_OK, "Cold WAL fixture did not close normally")
        writer = nil
    }

    private static func sqliteStrings(_ url: URL, query: String) throws -> [String] {
        var db: OpaquePointer?
        guard sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            if let db { sqlite3_close(db) }
            throw CheckFailure(description: "Cannot read SQLite fixture")
        }
        defer { sqlite3_close(db) }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            throw CheckFailure(description: "Cannot query SQLite fixture: \(String(cString: sqlite3_errmsg(db)))")
        }
        defer { sqlite3_finalize(statement) }
        var values: [String] = []
        var result = sqlite3_step(statement)
        while result == SQLITE_ROW {
            if let value = sqlite3_column_text(statement, 0) { values.append(String(cString: value)) }
            result = sqlite3_step(statement)
        }
        try require(result == SQLITE_DONE, "SQLite fixture query failed")
        return values
    }

    private static func sqliteBackup(from source: URL, to target: URL) throws {
        var input: OpaquePointer?, output: OpaquePointer?
        defer { if let output { sqlite3_close(output) }; if let input { sqlite3_close(input) } }
        try require(sqlite3_open_v2(source.path, &input, SQLITE_OPEN_READONLY, nil) == SQLITE_OK, "Cannot open legacy SQLite source")
        try require(sqlite3_open_v2(target.path, &output, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, nil) == SQLITE_OK, "Cannot create temporary migration copy")
        guard let operation = sqlite3_backup_init(output, "main", input, "main") else { throw CheckFailure(description: "SQLite backup could not start") }
        let step = sqlite3_backup_step(operation, -1), finish = sqlite3_backup_finish(operation)
        try require(step == SQLITE_DONE && finish == SQLITE_OK, "SQLite backup did not complete")
    }

    static var all: [(String, () throws -> Void)] { [
        ("Idea CRUD, immediate saves, pin/archive and Observation", ideaCRUDAndObservation),
        ("Idea conversion preserves content; goal deletion nullifies links", conversionAndGoalNullification),
        ("Invalid Idea mutations rollback atomically", invalidIdeaMutationsRollback),
        ("Direct task editing captures ordered planning events", directTaskEditsCaptureHistory),
        ("Captured plan days survive Shanghai/Los Angeles travel", planningAssignmentsSurviveTimeZoneChanges),
        ("V2 Idea/history round trip preserves equal-time event order", v2RoundTripAndEqualTimeOrder),
        ("Genuine v1 JSON restoration establishes current baselines", genuineV1Restoration),
        ("Invalid Idea/history imports retain saved and pending data", invalidV2ImportsAreAtomic),
        ("Recurring migration preserves occurrence and baseline IDs", recurringMigrationKeepsBaselines),
        ("Genuine v1 SQLite migration on isolated online backup", legacySQLiteMigration),
        ("Safety snapshot handles cold and live WAL stores without sidecars", safetySnapshotsHandleColdAndLiveWAL)
    ] }
}
