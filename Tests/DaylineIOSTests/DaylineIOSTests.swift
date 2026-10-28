import XCTest
import DaylineCore
import DaylineData

@MainActor
final class DaylineIOSTests: XCTestCase {
    func testTaskCreateEditCompleteAndDelete() throws {
        let (store, url) = try makeStore()
        let created = try XCTUnwrap(store.addTask(title: "  买牛奶  ", notes: "原味"))
        XCTAssertEqual(created.title, "买牛奶")
        created.notes = "两盒"
        created.priority = .high
        store.save()
        XCTAssertNil(store.errorMessage)
        store.toggleTask(created)
        XCTAssertTrue(created.isCompleted)
        XCTAssertNotNil(created.completedAt)
        store.toggleTask(created)
        XCTAssertFalse(created.isCompleted)
        let id = created.id
        let reopened = try reopen(url)
        XCTAssertEqual(reopened.tasks.first { $0.id == id }?.notes, "两盒")
        XCTAssertEqual(reopened.tasks.first { $0.id == id }?.priority, .high)
        let again = try XCTUnwrap(reopened.tasks.first { $0.id == id })
        reopened.deleteTask(again)
        XCTAssertFalse(reopened.tasks.contains { $0.id == id })
    }

    func testGoalLinkSurvivesEditAndDetachesOnDelete() throws {
        let (store, url) = try makeStore()
        let long = try XCTUnwrap(store.addGoal(title: "长期方向", kind: .longTerm, areaID: store.areas.first?.id))
        let short = try XCTUnwrap(store.addGoal(title: "短期成果", kind: .shortTerm, areaID: long.areaID, parentGoalID: long.id))
        let task = try XCTUnwrap(store.addTask(title: "下一步", goalID: short.id))
        XCTAssertEqual(task.goalID, short.id)
        XCTAssertEqual(task.areaID, long.areaID)
        short.progress = 0.4
        store.setGoalStatus(short, to: .active)
        let reopened = try reopen(url)
        let restoredShort = try XCTUnwrap(reopened.goals.first { $0.id == short.id })
        XCTAssertEqual(restoredShort.parentGoalID, long.id)
        XCTAssertEqual(reopened.tasks.first { $0.id == task.id }?.goalID, short.id)
        reopened.deleteGoal(restoredShort)
        XCTAssertNil(reopened.tasks.first { $0.id == task.id }?.goalID)
        XCTAssertTrue(reopened.goals.contains { $0.id == long.id })
    }

    func testDailySuccessorUsesSharedIdentityAndDoesNotDuplicate() throws {
        let (store, url) = try makeStore()
        let calendar = Calendar.current
        let start = calendar.date(from: DateComponents(year: 2026, month: 11, day: 2))!
        let task = try XCTUnwrap(store.addTask(title: "每天阅读", scheduledDate: start))
        task.repeatRule = .daily
        store.save()
        store.toggleTask(task)
        let successor = try XCTUnwrap(store.tasks.first { $0.id != task.id })
        let nextDay = try XCTUnwrap(DaylineDates.nextOccurrence(after: start, rule: .daily, now: start, calendar: calendar))
        let expected = DaylineIdentity.recurrenceSuccessorID(source: task.id, occurrence: nextDay, calendar: calendar)
        XCTAssertEqual(successor.id, expected)
        XCTAssertFalse(successor.isCompleted)
        store.toggleTask(task)
        store.toggleTask(task)
        XCTAssertEqual(store.tasks.filter { $0.id == expected }.count, 1)
        XCTAssertEqual(store.planningEvents.filter { $0.taskID == task.id && $0.kind == .completed }.count, 2)
        XCTAssertTrue(store.planningEvents.contains { $0.taskID == task.id && $0.kind == .reopened })
        let reopened = try reopen(url)
        XCTAssertEqual(reopened.tasks.first { $0.id == expected }?.repeatRule, .daily)
    }

    func testIdeaAutosaveFieldsConvertAndReopen() throws {
        let (store, url) = try makeStore()
        let idea = try XCTUnwrap(store.addIdea(title: "念头", body: "第一句"))
        store.updateIdea(idea, title: "念头", body: "更完整的一句", areaID: nil, goalID: nil)
        store.setIdeaPinned(idea, to: true)
        let task = try XCTUnwrap(store.taskFromIdea(idea))
        XCTAssertEqual(task.title, "念头")
        XCTAssertEqual(task.notes, "更完整的一句")
        XCTAssertFalse(store.ideas.isEmpty)
        store.setIdeaArchived(idea, to: true)
        let reopened = try reopen(url)
        let restored = try XCTUnwrap(reopened.ideas.first { $0.id == idea.id })
        XCTAssertTrue(restored.isPinned)
        XCTAssertTrue(restored.isArchived)
        XCTAssertEqual(restored.body, "更完整的一句")
        XCTAssertTrue(reopened.tasks.contains { $0.id == task.id })
    }

    func testPlanDateStaysOnTheCapturedCalendarDay() throws {
        var shanghai = Calendar(identifier: .gregorian)
        shanghai.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        let late = shanghai.date(from: DateComponents(year: 2026, month: 10, day: 25, hour: 23, minute: 30))!
        XCTAssertEqual(DaylineScheduling.stableDayKey(late, capturedIn: shanghai.timeZone), "2026-10-25")
        var losAngeles = Calendar(identifier: .gregorian)
        losAngeles.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        XCTAssertEqual(DaylineDateSelection.dayKey(late, calendar: losAngeles), "2026-10-25")
        let early = shanghai.date(from: DateComponents(year: 2026, month: 10, day: 25, hour: 2))!
        XCTAssertEqual(DaylineScheduling.stableDayKey(early, capturedIn: shanghai.timeZone), "2026-10-25")
        XCTAssertEqual(DaylineDateSelection.dayKey(early, calendar: losAngeles), "2026-10-24")

        let (store, url) = try makeStore()
        let midnight = shanghai.startOfDay(for: late)
        let task = try XCTUnwrap(store.addTask(title: "跨午夜", scheduledDate: midnight))
        let reopened = try reopen(url)
        let stored = try XCTUnwrap(reopened.tasks.first { $0.id == task.id }?.scheduledDate)
        XCTAssertEqual(stored, midnight)
        XCTAssertEqual(DaylineScheduling.stableDayKey(stored, capturedIn: shanghai.timeZone), "2026-10-25")
    }

    func testSharedDailyReviewModelPersistsWithoutChangingExistingEntities() throws {
        let (store, url) = try makeStore()
        let task = try XCTUnwrap(store.addTask(title: "iPhone 原有任务"))
        let review = try XCTUnwrap(store.updateDailyReview(dayKey: "2026-10-28", timeZoneID: "Asia/Shanghai",
                                                          learned: "共享模型可以读取", growth: "", nextStep: "", freeformNotes: ""))
        XCTAssertEqual(review.id, DailyReviewDay.stableID(for: "2026-10-28"))
        let reopened = try reopen(url)
        XCTAssertEqual(reopened.dailyReviews.first?.learned, "共享模型可以读取")
        XCTAssertEqual(reopened.tasks.first { $0.id == task.id }?.title, "iPhone 原有任务")
        XCTAssertEqual(reopened.areas.count, 3)
    }

    private func makeStore() throws -> (DaylineStore, URL) {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("Dayline-iOSTest-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("Dayline.store")
        return try (DaylineStore(container: DaylineStore.makeContainer(url: url)), url)
    }

    private func reopen(_ url: URL) throws -> DaylineStore {
        try DaylineStore(container: DaylineStore.makeContainer(url: url))
    }
}
