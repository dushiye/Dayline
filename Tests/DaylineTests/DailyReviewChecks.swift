import Foundation
import SwiftData
import DaylineCore
import DaylineData
#if canImport(Dayline) && !DAYLINE_SCRIPT_TEST
@testable import Dayline
#endif

@MainActor
enum DailyReviewChecks {
    static func crudAndOneReviewPerDay() throws {
        let store = try RuleChecks.store()
        let day = "2026-10-28"
        let blank = store.updateDailyReview(dayKey: day, timeZoneID: "Asia/Shanghai",
                                            learned: " \n", growth: "", nextStep: "", freeformNotes: "")
        try require(blank == nil && store.dailyReviews.isEmpty, "Blank draft created a persistent review")

        let created = try unwrap(store.updateDailyReview(dayKey: day, timeZoneID: "Asia/Shanghai",
                                                        learned: "用自己的语言解释概念", growth: "", nextStep: "", freeformNotes: ""),
                                 "Review creation failed")
        let id = created.id, createdAt = created.createdAt
        try require(id == DailyReviewDay.stableID(for: day), "Review business identity is not stable")
        let updated = try unwrap(store.updateDailyReview(dayKey: day, timeZoneID: "America/Los_Angeles",
                                                        learned: "理解得更清楚", growth: "完成了小实验",
                                                        nextStep: "明天写出例子", freeformNotes: "问题仍需验证"),
                                 "Review update failed")
        try require(store.dailyReviews.count == 1 && updated.id == id && updated.createdAt == createdAt,
                    "Editing one day duplicated or replaced the review")
        try require(updated.timeZoneID == "Asia/Shanghai", "Editing after travel changed the captured day timezone")
        try require(updated.growth == "完成了小实验" && updated.nextStep == "明天写出例子", "Review fields were not updated")

        _ = store.updateDailyReview(dayKey: day, timeZoneID: "Asia/Shanghai",
                                    learned: "", growth: "", nextStep: "", freeformNotes: "")
        try require(store.errorMessage != nil && store.dailyReviews.count == 1
                    && store.dailyReviews[0].learned == "理解得更清楚",
                    "Clearing every field bypassed confirmed deletion or changed saved content")

        _ = store.updateDailyReview(dayKey: "2026-02-30", timeZoneID: "Asia/Shanghai",
                                    learned: "坏日期", growth: "", nextStep: "", freeformNotes: "")
        try require(store.errorMessage != nil && store.dailyReviews.count == 1, "Invalid day was accepted or changed data")
        store.deleteDailyReview(updated)
        try require(store.errorMessage == nil && store.dailyReviews.isEmpty, "Review deletion failed")
    }

    static func autosaveSessionRetainsFailureAndPersists() throws {
        let directory = temporaryDirectory("Autosave")
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appendingPathComponent("Dayline.store")
        let store = try DaylineStore(container: DaylineStore.makeContainer(url: storeURL))
        let session = DailyReviewDraftSession(now: Date(), timeZone: TimeZone(identifier: "Asia/Shanghai")!)
        session.learned = "防抖结束后保存的中文\n第二行"
        session.isDirty = true
        try require(session.persist(to: store), "Autosave session could not commit")
        try require(!session.isDirty && session.lastSavedAt != nil, "Successful autosave did not clear dirty state")
        let day = session.selectedDayKey
        let reopened = try DaylineStore(container: DaylineStore.makeContainer(url: storeURL))
        try require(reopened.dailyReview(for: day)?.learned == session.learned, "Autosaved review did not survive reopen")

        session.selectedDayKey = "invalid"
        session.learned = "失败时必须留在草稿中"
        session.isDirty = true
        try require(!session.persist(to: reopened), "Invalid autosave unexpectedly succeeded")
        try require(session.isDirty && session.learned == "失败时必须留在草稿中", "Failed autosave discarded the draft")
    }

    static func civilDayIdentityAcrossZonesAndDST() throws {
        let shanghai = TimeZone(identifier: "Asia/Shanghai")!
        let losAngeles = TimeZone(identifier: "America/Los_Angeles")!
        let instant = RuleChecks.date(2026, 3, 8, 1, 30, calendar: RuleChecks.calendar("Asia/Shanghai"))
        try require(DailyReviewDay.key(for: instant, timeZone: shanghai) == "2026-03-08", "Shanghai day key is wrong")
        try require(DailyReviewDay.key(for: instant, timeZone: losAngeles) == "2026-03-07", "Los Angeles day key is wrong")
        try require(DailyReviewDay.addingDays(1, to: "2026-03-08") == "2026-03-09", "Spring DST day navigation failed")
        try require(DailyReviewDay.addingDays(1, to: "2026-11-01") == "2026-11-02", "Autumn DST day navigation failed")
        try require(DailyReviewDay.addingDays(-1, to: "2027-01-01") == "2026-12-31", "Cross-year day navigation failed")
        try require(!DailyReviewDay.isValid("2026-02-29") && DailyReviewDay.isValid("2028-02-29"), "Leap-day validation failed")
        let date = try unwrap(DailyReviewDay.date(for: "2026-03-08", timeZone: losAngeles), "Could not reconstruct captured day")
        try require(DailyReviewDay.key(for: date, timeZone: losAngeles) == "2026-03-08", "DST reconstruction shifted the review day")
    }

    static func additiveMigrationPreservesLegacyEntities() throws {
        let directory = temporaryDirectory("V11Migration")
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("Dayline.store")
        let goalID = UUID(), taskID = UUID(), ideaID = UUID(), eventID = UUID()
        let seedStore = try RuleChecks.store()
        let seedValues = seedStore.areas.map { ($0.id, $0.name, $0.symbol, $0.colorKey, $0.sortOrder) }
        let learningID = try unwrap(seedValues.first { $0.1 == "Learning" }?.0, "Learning seed missing")
        let researchID = try unwrap(seedValues.first { $0.1 == "Research" }?.0, "Research seed missing")
        do {
            let schema = Schema([Area.self, Goal.self, DayTask.self, Idea.self, PlanningEventEntity.self])
            let configuration = ModelConfiguration("Dayline", schema: schema, url: url, allowsSave: true, cloudKitDatabase: .none)
            let container = try ModelContainer(for: schema, configurations: [configuration])
            let context = ModelContext(container)
            for seed in seedValues {
                context.insert(Area(id: seed.0, name: seed.1, symbol: seed.2, colorKey: seed.3, sortOrder: seed.4))
            }
            context.insert(Goal(id: goalID, title: "旧目标", kind: .longTerm, areaID: researchID))
            context.insert(DayTask(id: taskID, title: "旧任务", areaID: researchID,
                                   scheduledDate: RuleChecks.date(2026, 10, 28), goalID: goalID))
            context.insert(Idea(id: ideaID, title: "旧灵感", body: "保留正文", areaID: learningID))
            let record = PlanningEventRecord(id: eventID, taskID: taskID, kind: .planned,
                                             occurredAt: RuleChecks.date(2026, 10, 27), dayKey: "2026-10-28",
                                             timeZoneID: "Asia/Shanghai", taskTitle: "旧任务",
                                             areaID: researchID)
            context.insert(try PlanningEventEntity(record, sequence: 1))
            try context.save()
        }

        let migrated = try DaylineStore(container: DaylineStore.makeContainer(url: url))
        try require(Set(migrated.areas.map(\.id)) == Set(seedValues.map { $0.0 }), "Migration changed area identities")
        try require(migrated.goals.map(\.id) == [goalID] && migrated.tasks.map(\.id) == [taskID], "Migration lost goal/task identity")
        try require(migrated.ideas.map(\.id) == [ideaID] && migrated.planningEvents.map(\.id) == [eventID], "Migration lost Idea/history identity")
        try require(migrated.dailyReviews.isEmpty, "Migration fabricated a review")
        _ = migrated.updateDailyReview(dayKey: "2026-10-28", timeZoneID: "Asia/Shanghai",
                                       learned: "升级后可以记录", growth: "", nextStep: "", freeformNotes: "")
        let reopened = try DaylineStore(container: DaylineStore.makeContainer(url: url))
        try require(reopened.tasks.first?.id == taskID && reopened.goals.first?.id == goalID
                    && reopened.ideas.first?.id == ideaID && reopened.planningEvents.first?.id == eventID,
                    "Post-migration reopen changed legacy identities")
        try require(reopened.dailyReviews.first?.learned == "升级后可以记录", "Migrated store cannot persist reviews")
        try require(FileManager.default.fileExists(atPath: url.path + ".before-daily-review.sqlite"),
                    "Migration did not create the dedicated recovery snapshot")
    }

    static func genuineV1SQLiteMigrationPreservesSource() throws {
        let source = DaylineTestFixtures.url("v1.store")
        let sourceData = try Data(contentsOf: source)
        let directory = temporaryDirectory("V1Migration")
        defer { try? FileManager.default.removeItem(at: directory) }
        let copy = directory.appendingPathComponent("Dayline.store")
        try FileManager.default.copyItem(at: source, to: copy)
        let store = try DaylineStore(container: DaylineStore.makeContainer(url: copy))
        let taskIDs = store.tasks.map(\.id)
        let goalIDs = store.goals.map(\.id)
        try require(store.areas.count == 3 && store.tasks.count == 1 && store.goals.count == 1,
                    "Genuine v1 SQLite counts changed during migration")
        try require(store.ideas.isEmpty && store.dailyReviews.isEmpty, "Genuine v1 migration fabricated new entities")
        _ = store.updateDailyReview(dayKey: "2026-10-28", timeZoneID: "Asia/Shanghai",
                                    learned: "迁移测试", growth: "", nextStep: "", freeformNotes: "")
        let reopened = try DaylineStore(container: DaylineStore.makeContainer(url: copy))
        try require(reopened.tasks.map(\.id) == taskIDs && reopened.goals.map(\.id) == goalIDs,
                    "Genuine v1 IDs changed after adding DailyReview")
        let sourceAfter = try Data(contentsOf: source)
        try require(sourceAfter == sourceData, "Migration mutated the checked-in source fixture")
    }

    static func jsonV1V2V3CompatibilityAndAtomicRejection() throws {
        let source = try RuleChecks.store()
        _ = source.addIdea(title: "兼容灵感", body: "保留")
        _ = source.addTask(title: "兼容任务", scheduledDate: Date())
        _ = source.updateDailyReview(dayKey: "2026-10-28", timeZoneID: "Asia/Shanghai",
                                     learned: "备份中的回顾", growth: "持续进步", nextStep: "继续整理", freeformNotes: "尾注")
        let v3Data = try source.exportBackup()
        let v3 = try DaylineBackup.decoder().decode(DaylineBackup.self, from: v3Data)
        try require(v3.schemaVersion == 3 && v3.dailyReviews.count == 1, "V3 backup omitted the review")
        let roundTrip = try RuleChecks.store()
        try roundTrip.restoreBackup(v3Data)
        try require(roundTrip.dailyReviews.first?.learned == "备份中的回顾" && roundTrip.ideas.count == 1,
                    "V3 round trip lost content")

        var v2Object = try JSONSerialization.jsonObject(with: v3Data) as! [String: Any]
        v2Object["schemaVersion"] = 2
        v2Object.removeValue(forKey: "dailyReviews")
        let v2Data = try JSONSerialization.data(withJSONObject: v2Object)
        let v2 = try DaylineBackup.decoder().decode(DaylineBackup.self, from: v2Data)
        try v2.validate()
        try require(v2.dailyReviews.isEmpty && v2.ideas.count == 1, "Genuine field-absent v2 did not decode")
        try roundTrip.restoreBackup(v2Data)
        try require(roundTrip.dailyReviews.isEmpty && roundTrip.ideas.count == 1, "V2 replacement did not clear newer reviews")

        let v1Data = try Data(contentsOf: DaylineTestFixtures.url("v1-backup.json"))
        let v1 = try DaylineBackup.decoder().decode(DaylineBackup.self, from: v1Data)
        try v1.validate()
        _ = roundTrip.updateDailyReview(dayKey: "2026-10-29", timeZoneID: "Asia/Shanghai",
                                        learned: "将被旧备份替换", growth: "", nextStep: "", freeformNotes: "")
        try roundTrip.restoreBackup(v1Data)
        try require(roundTrip.dailyReviews.isEmpty && roundTrip.ideas.isEmpty, "V1 replacement retained newer-only records")

        try roundTrip.restoreBackup(v3Data)
        let beforeIDs = Set(roundTrip.tasks.map(\.id)), beforeReview = roundTrip.dailyReviews.first?.learned
        var invalid = v3
        invalid.dailyReviews[0].timeZoneID = "Invalid/Zone"
        do {
            try roundTrip.restoreBackup(DaylineBackup.encoder().encode(invalid))
            throw CheckFailure(description: "Invalid review backup was accepted")
        } catch is CheckFailure { throw CheckFailure(description: "Invalid review backup was accepted") }
        catch { }
        try roundTrip.refresh()
        try require(Set(roundTrip.tasks.map(\.id)) == beforeIDs && roundTrip.dailyReviews.first?.learned == beforeReview,
                    "Rejected review backup mutated current data")
        do {
            try roundTrip.restoreBackup(Data("{damaged".utf8))
            throw CheckFailure(description: "Damaged JSON was accepted")
        } catch is CheckFailure { throw CheckFailure(description: "Damaged JSON was accepted") }
        catch { }
        try require(roundTrip.dailyReviews.first?.learned == beforeReview, "Damaged JSON discarded the saved review")
    }

    static func checkpointBackupCapturesLateReviewWithoutOverwrite() throws {
        let directory = temporaryDirectory("Checkpoint")
        defer { try? FileManager.default.removeItem(at: directory) }
        let backups = directory.appendingPathComponent("Backups", isDirectory: true)
        let store = try DaylineStore(container: DaylineStore.makeContainer(url: directory.appendingPathComponent("Dayline.store")),
                                     automaticBackupDirectory: backups)
        let auto = try FileManager.default.contentsOfDirectory(at: backups, includingPropertiesForKeys: nil)
            .first { $0.lastPathComponent.hasPrefix("Dayline-Auto-") }
        let first = try unwrap(auto, "Initial daily backup missing")
        let initialData = try Data(contentsOf: first)
        let initial = try DaylineBackup.decoder().decode(DaylineBackup.self, from: initialData)
        try require(initial.dailyReviews.isEmpty, "Initial backup unexpectedly contains a late review")

        _ = store.updateDailyReview(dayKey: "2026-10-28", timeZoneID: "Asia/Shanghai",
                                    learned: "当天晚些时候写下的内容", growth: "", nextStep: "", freeformNotes: "")
        store.runReviewCheckpointBackup()
        _ = store.updateDailyReview(dayKey: "2026-10-28", timeZoneID: "Asia/Shanghai",
                                    learned: "当天更晚的最终内容", growth: "", nextStep: "", freeformNotes: "")
        store.runReviewCheckpointBackup()
        let all = try FileManager.default.contentsOfDirectory(at: backups, includingPropertiesForKeys: nil)
        let checkpoints = all.filter { $0.lastPathComponent.hasPrefix("Dayline-Review-") }
        try require(checkpoints.count == 2, "Review checkpoints overwrote one another")
        let initialAfter = try Data(contentsOf: first)
        try require(initialAfter == initialData, "Late checkpoint overwrote the immutable daily backup")
        let documents = try checkpoints.map { try DaylineBackup.decoder().decode(DaylineBackup.self, from: Data(contentsOf: $0)) }
        try require(documents.contains { $0.dailyReviews.first?.learned == "当天晚些时候写下的内容" }
                    && documents.contains { $0.dailyReviews.first?.learned == "当天更晚的最终内容" },
                    "Append-only checkpoints did not capture both late review states")
    }

    private static func temporaryDirectory(_ label: String) -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Dayline-DailyReview-\(label)-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private static func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        try RuleChecks.require(condition(), message)
    }

    private static func unwrap<T>(_ value: T?, _ message: String) throws -> T {
        guard let value else { throw CheckFailure(description: message) }
        return value
    }
}
