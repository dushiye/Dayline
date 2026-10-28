import Foundation
import SwiftData
#if canImport(Dayline) && !DAYLINE_SCRIPT_TEST
@testable import Dayline
#endif
import DaylineCore
import DaylineData

@MainActor
enum SharedCoreChecks {
    static func sameBusinessUUIDIsNotOnePersistentObject() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("Dayline-TwoDevice-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let mac = try DaylineStore(container: DaylineStore.makeContainer(url: directory.appendingPathComponent("mac.store")))
        let phone = try DaylineStore(container: DaylineStore.makeContainer(url: directory.appendingPathComponent("phone.store")))
        let macArea = try unwrap(mac.areas.first { $0.name == "Learning" }, "Mac seed missing")
        let phoneArea = try unwrap(phone.areas.first { $0.name == "Learning" }, "Phone seed missing")
        try require(macArea.id == phoneArea.id, "Seed business UUIDs diverged")
        let macPersistent = String(describing: macArea.persistentModelID)
        let phonePersistent = String(describing: phoneArea.persistentModelID)
        try require(macPersistent != phonePersistent, "Two stores produced one PersistentIdentifier")
        guard case .duplicateBusinessID(let keep, let discard) = DaylineMerge.classify(
            TrackedRecord(businessID: macArea.id, persistentID: macPersistent, updatedAt: .distantPast),
            TrackedRecord(businessID: phoneArea.id, persistentID: phonePersistent, updatedAt: .distantFuture)
        ) else { throw CheckFailure(description: "Same business UUID was treated as distinct or as one object") }
        try require(keep.persistentID == phonePersistent && discard.count == 1, "Merge did not keep one persistent row")
    }

    static func legacyFixtureEditRoundTrip() throws {
        let source = DaylineTestFixtures.url("v1.store")
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("Dayline-FixtureEdit-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let copy = directory.appendingPathComponent("Dayline.store")
        try FileManager.default.copyItem(at: source, to: copy)
        let opened = try DaylineStore(container: DaylineStore.makeContainer(url: copy))
        try require(opened.areas.count == 3 && opened.goals.count == 1 && opened.tasks.count == 1 && opened.ideas.isEmpty, "Fixture counts changed on open")
        let taskID = try unwrap(opened.tasks.first?.id, "Fixture task missing")
        let goalID = try unwrap(opened.goals.first?.id, "Fixture goal missing")
        opened.tasks[0].title = "编辑后的夹具任务"
        opened.save()
        try require(opened.errorMessage == nil, "Saving the fixture copy failed")
        let reopened = try DaylineStore(container: DaylineStore.makeContainer(url: copy))
        try require(reopened.tasks.count == 1 && reopened.tasks[0].id == taskID, "Reopen changed the task identity")
        try require(reopened.tasks[0].title == "编辑后的夹具任务", "Reopen lost the edit")
        try require(reopened.goals.first?.id == goalID && reopened.areas.count == 3, "Reopen changed goals or areas")
        try require(reopened.tasks[0].goalID == goalID, "Reopen dropped the goal link")
    }

    /// Two temp stores, copied by backup. Same successor business UUID, different persistent rows.
    /// Independently recorded history events do not share an id, so a later import must not treat
    /// a matching task UUID as proof that the history rows are the same object.
    static func twoStoresShareSuccessorButNotPersistentIdentity() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("Dayline-TwoStore-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let mac = try DaylineStore(container: DaylineStore.makeContainer(url: directory.appendingPathComponent("mac.store")))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        let day = calendar.date(from: DateComponents(year: 2026, month: 11, day: 2))!
        let created = try unwrap(mac.addTask(title: "两台设备的重复任务", scheduledDate: day), "Mac task was rejected")
        created.repeatRule = .daily
        mac.save()
        try require(mac.errorMessage == nil, "Saving the source task failed")
        let sourceID = created.id
        let backup = try mac.exportBackup()

        let phone = try DaylineStore(container: DaylineStore.makeContainer(url: directory.appendingPathComponent("phone.store")))
        try phone.restoreBackup(backup)
        let macTask = try unwrap(mac.tasks.first { $0.id == sourceID }, "Mac lost the source task")
        let phoneTask = try unwrap(phone.tasks.first { $0.id == sourceID }, "Phone did not restore the source task")
        let macSourcePersistent = String(describing: macTask.persistentModelID)
        let phoneSourcePersistent = String(describing: phoneTask.persistentModelID)
        try require(macSourcePersistent != phoneSourcePersistent, "Restoring the same business UUID reused one PersistentIdentifier")

        mac.toggleTask(macTask)
        phone.toggleTask(phoneTask)
        try require(mac.errorMessage == nil && phone.errorMessage == nil, "Completion failed on one store")
        try require(macTask.isCompleted && phoneTask.isCompleted, "Both devices did not complete the shared task")
        let macSuccessor = try unwrap(mac.tasks.first { $0.id != sourceID }, "Mac did not create a successor")
        let phoneSuccessor = try unwrap(phone.tasks.first { $0.id != sourceID }, "Phone did not create a successor")
        try require(macSuccessor.id == phoneSuccessor.id, "Successor business UUIDs diverged")
        let macSuccessorPersistent = String(describing: macSuccessor.persistentModelID)
        let phoneSuccessorPersistent = String(describing: phoneSuccessor.persistentModelID)
        try require(macSuccessorPersistent != phoneSuccessorPersistent, "Two stores created one successor row")
        try require(mac.tasks.count == 2 && phone.tasks.count == 2, "A store absorbed the other device's row")
        guard case .duplicateBusinessID(let keep, let discard) = DaylineMerge.classify(
            TrackedRecord(businessID: macSuccessor.id, persistentID: macSuccessorPersistent, updatedAt: .distantPast),
            TrackedRecord(businessID: phoneSuccessor.id, persistentID: phoneSuccessorPersistent, updatedAt: .distantFuture)
        ) else { throw CheckFailure(description: "Matching successor UUIDs were treated as one persistent object") }
        try require(keep.persistentID == phoneSuccessorPersistent && discard.map(\.persistentID) == [macSuccessorPersistent], "Merge did not keep exactly one successor row")

        let macCompleted = mac.planningEvents.filter { $0.taskID == sourceID && $0.kind == .completed }
        let phoneCompleted = phone.planningEvents.filter { $0.taskID == sourceID && $0.kind == .completed }
        try require(macCompleted.count == 1 && phoneCompleted.count == 1, "Each device should record one completion")
        try require(macCompleted[0].id != phoneCompleted[0].id, "Independent history rows shared an event id")
        try require(DaylineMerge.importEvent(existingIDs: [macCompleted[0].id], existingSameTransition: macCompleted[0].id, incoming: macCompleted[0].id) == .alreadyStored, "Re-import of the same history id was not recognized")
        try require(DaylineMerge.importEvent(existingIDs: [macCompleted[0].id], existingSameTransition: nil, incoming: phoneCompleted[0].id) == .insert, "A different history row was treated as already stored")
        let stable = DaylineIdentity.planningEventID(taskID: sourceID, kind: PlanningEventKind.completed.rawValue, dayKey: macCompleted[0].dayKey ?? "", generation: 1)
        try require(DaylineMerge.importEvent(existingIDs: [stable], existingSameTransition: stable, incoming: stable) == .alreadyStored, "Stable history identity did not dedup an identical generation")

        mac.toggleTask(macTask)
        mac.toggleTask(macTask)
        let sourceEvents = mac.planningEvents.filter { $0.taskID == sourceID }
        try require(sourceEvents.filter { $0.kind == .completed }.count == 2, "Second completion was not recorded")
        try require(sourceEvents.contains { $0.kind == .reopened }, "Reopen was not recorded")
        try require(Set(sourceEvents.map(\.id)).count == sourceEvents.count, "History event ids collided inside one store")
        try require(mac.tasks.filter { $0.id == macSuccessor.id }.count == 1, "Reopen and second completion created another successor")

        let beforeDelete = try mac.exportBackup()
        mac.deleteTask(macTask)
        try require(mac.errorMessage == nil && !mac.tasks.contains { $0.id == sourceID }, "Delete did not remove the source task")
        try require(mac.planningEvents.contains { $0.taskID == sourceID && $0.kind == .deleted }, "Delete did not record history")
        try mac.restoreBackup(beforeDelete)
        let restored = try unwrap(mac.tasks.first { $0.id == sourceID }, "Restore lost the source business UUID")
        try require(restored.title == "两台设备的重复任务" && mac.tasks.contains { $0.id == macSuccessor.id }, "Restore lost the successor")
        try require(String(describing: restored.persistentModelID) != macSourcePersistent, "Delete and restore reused the original PersistentIdentifier")
        try require(!mac.planningEvents.contains { $0.taskID == sourceID && $0.kind == .deleted }, "Restore kept a delete that was not in the backup")
    }

    private static func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        if !condition() { throw CheckFailure(description: message) }
    }

    private static func unwrap<T>(_ value: T?, _ message: String) throws -> T {
        guard let value else { throw CheckFailure(description: message) }
        return value
    }
}
