import XCTest
@testable import DaylineCore

final class IdentityTests: XCTestCase {
    func testTwoDevicesCreateTheSameSuccessor() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        let source = UUID(uuidString: "AAAAAAAA-BBBB-4CCC-8DDD-EEEEEEEEEEEE")!
        let day = calendar.date(from: DateComponents(year: 2026, month: 10, day: 27))!
        let mac = DaylineIdentity.recurrenceSuccessorID(source: source, occurrence: day, calendar: calendar)
        let phone = DaylineIdentity.recurrenceSuccessorID(source: source, occurrence: day, calendar: calendar)
        XCTAssertEqual(mac, phone)
    }

    func testCompletionReopenAndSecondCompletionDoNotShareOneID() {
        let task = UUID()
        let first = DaylineIdentity.planningEventID(taskID: task, kind: "completed", dayKey: "2026-10-26", generation: 1)
        let reopen = DaylineIdentity.planningEventID(taskID: task, kind: "reopened", dayKey: "2026-10-26", generation: 2)
        let second = DaylineIdentity.planningEventID(taskID: task, kind: "completed", dayKey: "2026-10-26", generation: 3)
        XCTAssertEqual(Set([first, reopen, second]).count, 3)
        XCTAssertEqual(DaylineIdentity.planningEventID(taskID: task, kind: "completed", dayKey: "2026-10-26", generation: 1), first)
    }

    func testMissedIntermediateEventIsAConflictNotASilentMerge() {
        let task = UUID()
        let macSecond = DaylineIdentity.planningEventID(taskID: task, kind: "completed", dayKey: "2026-10-26", generation: 3)
        let phoneSecond = DaylineIdentity.planningEventID(taskID: task, kind: "completed", dayKey: "2026-10-26", generation: 2)
        let decision = DaylineMerge.importEvent(existingIDs: [macSecond], existingSameTransition: macSecond, incoming: phoneSecond)
        guard case .conflictingGeneration(let existing, let incoming) = decision else {
            return XCTFail("Expected a generation conflict")
        }
        XCTAssertEqual(existing, macSecond)
        XCTAssertEqual(incoming, phoneSecond)
        XCTAssertEqual(DaylineMerge.importEvent(existingIDs: [macSecond], existingSameTransition: macSecond, incoming: macSecond), .alreadyStored)
    }

    func testSameBusinessUUIDWithDifferentPersistentIDsIsNotOneObject() {
        let business = UUID()
        let mac = TrackedRecord(businessID: business, persistentID: "store-A/Area/p1", updatedAt: Date(timeIntervalSince1970: 10))
        let phone = TrackedRecord(businessID: business, persistentID: "store-B/Area/p4", updatedAt: Date(timeIntervalSince1970: 20))
        guard case .duplicateBusinessID(let keep, let discard) = DaylineMerge.classify(mac, phone) else {
            return XCTFail("Expected duplicate business ids")
        }
        XCTAssertEqual(keep.persistentID, phone.persistentID)
        XCTAssertEqual(discard.map(\.persistentID), [mac.persistentID])
        XCTAssertEqual(DaylineIdentity.duplicateBusinessIDs([mac, phone], id: \.businessID), [business])
        XCTAssertEqual(DaylineMerge.classify(mac, mac), .sameObject)
    }

    func testCapturedDayKeyDoesNotFollowTheViewerTimeZone() {
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
    }

    func testDeleteAndRestoreAreDifferentEvents() {
        let task = UUID()
        let deleted = DaylineIdentity.planningEventID(taskID: task, kind: "deleted", dayKey: "2026-10-26", generation: 1)
        let restored = DaylineIdentity.planningEventID(taskID: task, kind: "planned", dayKey: "2026-10-26", generation: 2)
        XCTAssertNotEqual(deleted, restored)
        XCTAssertEqual(DaylineMerge.importEvent(existingIDs: [deleted], existingSameTransition: nil, incoming: restored), .insert)
    }
}
