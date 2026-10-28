import XCTest
import DaylineCore
import DaylineData
@testable import Dayline

final class DaylineTests: XCTestCase {
    func testXCTestHostUsesTemporaryDatabase() throws {
#if SWIFT_PACKAGE
        throw XCTSkip("Xcode application-host isolation is covered by the Dayline.xcodeproj Test Action")
#else
        XCTAssertEqual(ProcessInfo.processInfo.environment["DAYLINE_XCTEST_MODE"], "1")
        let store = FileManager.default.temporaryDirectory
            .appendingPathComponent("Dayline-XCTest-\(ProcessInfo.processInfo.processIdentifier)", isDirectory: true)
            .appendingPathComponent("Dayline.store")
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.path), "XCTest host did not create its isolated QA store")
        let formal = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Dayline/Dayline.store")
        XCTAssertNotEqual(store.standardizedFileURL, formal.standardizedFileURL)
#endif
    }

    @MainActor func testTodayUsesEitherDateOnce() throws { try RuleChecks.todayUsesEitherDateOnce() }
    @MainActor func testOverdueAndCarryoverAreDistinct() throws { try RuleChecks.overdueAndCarryoverAreDistinct() }
    @MainActor func testDSTAndCalendarBoundaries() throws { try RuleChecks.dstAndCalendarBoundaries() }
    @MainActor func testInboxKeepsDueOnlyTasks() throws { try RuleChecks.inboxKeepsDueOnlyTasks() }
    @MainActor func testRejectsBlankAndTrimsTitles() throws { try RuleChecks.rejectsBlankAndTrimsTitles() }
    @MainActor func testGoalDeletionPreservesDescendantsAndTasks() throws { try RuleChecks.goalDeletionPreservesDescendantsAndTasks() }
    @MainActor func testRecurrenceIsIdempotent() throws { try RuleChecks.recurrenceIsIdempotent() }
    @MainActor func testRecurrenceSkipsMissedIntervals() throws { try RuleChecks.recurrenceSkipsMissedIntervals() }
    @MainActor func testBackupRoundTrip() throws { try RuleChecks.backupRoundTrip() }
    @MainActor func testRecurrenceDedupSurvivesBackupRestore() throws { try RuleChecks.recurrenceDedupSurvivesBackupRestore() }
    @MainActor func testInvalidGoalBackupsAreAtomic() throws { try RuleChecks.invalidGoalBackupsAreAtomic() }
    @MainActor func testRejectedBackupLeavesStoreIntact() throws { try RuleChecks.rejectedBackupLeavesStoreIntact() }
    @MainActor func testInvalidImportPreservesPendingEdits() throws { try RuleChecks.invalidImportPreservesPendingEdits() }
    @MainActor func testObservedModelsAndRollback() throws { try RuleChecks.observedModelsAndRollback() }
    @MainActor func testPersistenceSurvivesReopen() throws { try RuleChecks.persistenceSurvivesReopen() }
    @MainActor func testDemoIsExplicitAndIdempotent() throws { try RuleChecks.demoIsExplicitAndIdempotent() }

    @MainActor func testIdeaCRUDAndObservation() throws { try V11Checks.ideaCRUDAndObservation() }
    @MainActor func testIdeaConversionAndGoalNullification() throws { try V11Checks.conversionAndGoalNullification() }
    @MainActor func testInvalidIdeaMutationsRollback() throws { try V11Checks.invalidIdeaMutationsRollback() }
    @MainActor func testDirectTaskEditsCaptureHistory() throws { try V11Checks.directTaskEditsCaptureHistory() }
    @MainActor func testPlanningAssignmentsSurviveTimeZoneChanges() throws { try V11Checks.planningAssignmentsSurviveTimeZoneChanges() }
    @MainActor func testV2RoundTripAndEqualTimeOrder() throws { try V11Checks.v2RoundTripAndEqualTimeOrder() }
    @MainActor func testGenuineV1Restoration() throws { try V11Checks.genuineV1Restoration() }
    @MainActor func testInvalidV2ImportsAreAtomic() throws { try V11Checks.invalidV2ImportsAreAtomic() }
    @MainActor func testRecurringMigrationKeepsBaselines() throws { try V11Checks.recurringMigrationKeepsBaselines() }
    @MainActor func testLegacySQLiteMigration() throws { try V11Checks.legacySQLiteMigration() }
    @MainActor func testSafetySnapshotsHandleColdAndLiveWAL() throws { try V11Checks.safetySnapshotsHandleColdAndLiveWAL() }

    func testPlanningFourteenDays() throws { try PlanningChecks.fourteenDays() }
    func testPlanningInsufficientAndCurrentDay() throws { try PlanningChecks.insufficientAndCurrentDay() }
    func testPlanningDoesNotFabricateBaseline() throws { try PlanningChecks.noFabricatedBaseline() }
    func testPlanningRescheduleDeleteAndUndo() throws { try PlanningChecks.rescheduleDeleteAndUndo() }
    func testPlanningAdditionsAndActualCompletion() throws { try PlanningChecks.additionsAndActualCompletion() }
    func testPlanningCompletionUndoDedupAndRecurrence() throws { try PlanningChecks.completionUndoDedupAndRecurrence() }
    func testPlanningMidnightCapturedZoneAndAsOf() throws { try PlanningChecks.midnightCapturedZoneAndAsOf() }
    func testPlanningCoachSeparatesCauses() throws { try PlanningChecks.coachSeparatesCauses() }
    func testPlanningGapsAndThirtyDayWindow() throws { try PlanningChecks.gapsAndThirtyDayWindow() }
    func testPlanningTodayCapacityThreshold() throws { try PlanningChecks.todayCapacityThreshold() }
    func testPlanningFinishedTaskCannotInflateFutureAdherence() throws { try PlanningChecks.finishedTaskCannotInflateFutureAdherence() }
    func testPlanningReopenedCompletedBaselineBecomesObservedPlan() throws { try PlanningChecks.reopenedCompletedBaselineBecomesObservedPlan() }

    func testDateGridAndTimeZoneDay() throws { try DatePickerChecks.gridAndTimeZone() }
    @MainActor func testGoalTargetDateRoundTripsOnIsolatedStore() throws { try DatePickerChecks.goalDateRoundTrip() }
    @MainActor func testSameBusinessUUIDIsNotOnePersistentObject() throws { try SharedCoreChecks.sameBusinessUUIDIsNotOnePersistentObject() }
    @MainActor func testLegacyFixtureEditRoundTrip() throws { try SharedCoreChecks.legacyFixtureEditRoundTrip() }
    @MainActor func testTwoStoresShareSuccessorButNotPersistentIdentity() throws { try SharedCoreChecks.twoStoresShareSuccessorButNotPersistentIdentity() }

    @MainActor func testDailyReviewCRUDAndOnePerDay() throws { try DailyReviewChecks.crudAndOneReviewPerDay() }
    @MainActor func testDailyReviewAutosaveSessionAndReopen() throws { try DailyReviewChecks.autosaveSessionRetainsFailureAndPersists() }
    @MainActor func testDailyReviewCivilDayIdentityAcrossZonesAndDST() throws { try DailyReviewChecks.civilDayIdentityAcrossZonesAndDST() }
    @MainActor func testDailyReviewAdditiveV11Migration() throws { try DailyReviewChecks.additiveMigrationPreservesLegacyEntities() }
    @MainActor func testDailyReviewGenuineV1SQLiteMigration() throws { try DailyReviewChecks.genuineV1SQLiteMigrationPreservesSource() }
    @MainActor func testDailyReviewJSONCompatibilityAndAtomicRejection() throws { try DailyReviewChecks.jsonV1V2V3CompatibilityAndAtomicRejection() }
    @MainActor func testDailyReviewCheckpointBackups() throws { try DailyReviewChecks.checkpointBackupCapturesLateReviewWithoutOverwrite() }

    func testExportRenderingAndFileSafety() throws {
        try ExportChecks.run(directory: try temporaryExportDirectory("rendering"))
    }

    func testExportCancellationLeavesNoFiles() async throws {
        try await ExportChecks.cancellation(directory: try temporaryExportDirectory("cancellation"))
    }

    private func temporaryExportDirectory(_ label: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Dayline-XCTest-\(label)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }
}
