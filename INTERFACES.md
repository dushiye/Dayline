# Dayline shared contract

Deployment: macOS 14+, Swift 5 language mode; SwiftUI + SwiftData only. Package executable module `Dayline`. Native AppKit available. Root directory is this folder. Do not modify files owned by other agents; request changes through parent.

## File ownership
- Lead: Package.swift, Sources/Dayline/DaylineApp.swift, project/bundle generation, assets, integration fixes after handoff.
- A: Sources/Dayline/Views/** (including design tokens), exclusively. Root view is `DaylineRootView`, zero-argument initializer, reads `@Environment(DaylineStore.self) private var store`.
- B: Sources/Dayline/Models/**, exclusively: models, store, date logic, backup.
- C: Tests/**, Documentation/**, README.md, scripts/verify.sh. Do not own package or build script. Coordinate API changes.

## Model contract (B provides these exact APIs)
All model classes use SwiftData `PersistentModel`, stable UUID `id`. Mutable data is main-actor managed. The installed CLT does not ship SwiftDataMacros; the implementation explicitly provides the public schema/backing-data protocol and Observation accessors, including the generated model layout's backing field names. This is the single canonical SwiftData implementation, also compiled by Xcode.

`enum GoalKind: String, Codable, CaseIterable { case longTerm, shortTerm }`
`enum GoalStatus: String, Codable, CaseIterable { case active, completed, archived }`
`enum TaskPriority: Int, Codable, CaseIterable { case none = 0, low = 1, medium = 2, high = 3 }`
`enum RepeatRule: String, Codable, CaseIterable { case none, daily, weekly }`

`Area`: id: UUID, name: String (Learning/Research/Health), symbol: String, colorKey: String (blue/purple/green), sortOrder: Int.
`Goal`: id, title: String, notes: String, kind: GoalKind, status: GoalStatus, targetDate: Date?, progress: Double (0...1, explicit outcome progress), areaID: UUID?, parentGoalID: UUID?, createdAt: Date. Long-term goals are roots; a short-term goal may reference a long-term parent. Linked areas must be consistent.
`DayTask`: id, title: String, notes: String, areaID: UUID?, goalID: UUID?, scheduledDate: Date?, dueDate: Date?, isCompleted: Bool, completedAt: Date?, priority: TaskPriority, sortOrder: Double, repeatRule: RepeatRule, createdAt: Date. Extra recurrence fields allowed.

`@MainActor @Observable final class DaylineStore`:
- `let container: ModelContainer`, `var tasks: [DayTask]`, `var goals: [Goal]`, `var areas: [Area]`, `var errorMessage: String?`
- `init(container: ModelContainer) throws`
- `static func makeContainer(inMemory: Bool = false, url: URL? = nil) throws -> ModelContainer`
- `func refresh() throws`; `func save()` nonthrowing, reports failures via errorMessage.
- `@discardableResult func addTask(title: String, areaID: UUID? = nil, scheduledDate: Date? = nil, dueDate: Date? = nil, goalID: UUID? = nil) -> DayTask?` trims/rejects blank.
- `func toggleTask(_ task: DayTask)`; `func deleteTask(_ task: DayTask)`; `func reschedule(_ task: DayTask, to: Date?)`; `func reorderTasks(_ orderedIDs: [UUID])`
- `@discardableResult func addGoal(title: String, kind: GoalKind, areaID: UUID?, parentGoalID: UUID? = nil) -> Goal?`
- `func deleteGoal(_ goal: Goal)` nullifies references, preserves tasks and child goals.
- `func setGoalStatus(_ goal: Goal, to: GoalStatus)`
- `func exportBackup() throws -> Data`; `func restoreBackup(_ data: Data) throws` (fully validate before replacing; no silent damage)
- `func loadDemoData()` explicit only, idempotent.

`enum DaylineDates` static functions:
- `isToday(_ task: DayTask, now: Date = Date(), calendar: Calendar = .current) -> Bool` scheduled OR due today, distinct task identities.
- `isOverdue(_ task: DayTask, now: Date = Date(), calendar: Calendar = .current) -> Bool` open due before start of today.
- `isUnfinishedPast(_ task: DayTask, now: Date = Date(), calendar: Calendar = .current) -> Bool` open scheduled before today (carryover surfaced explicitly, never silently moved).
- `isInbox(_ task: DayTask) -> Bool` no area, no schedule, no goal; due date alone does not hide from Inbox.
- `occurs(_ task: DayTask, on date: Date, calendar: Calendar = .current) -> Bool` scheduled OR due on date.

## UI expectations
Chinese-first labels with English area names if appropriate. Refined native sidebar, default Today, no default demo. Today grouped by area plus unassigned. Carryover section with explicit reschedule. Sheets/popovers edit tasks/goals, native date pickers, no always-required metadata. Keep distinct explicit outcome vs action progress. Inbox, Upcoming 7-day navigation, goal tree and area pages. Search, command-N, drag ordering, export/restore controls if possible. State changes through store methods or direct model edit + save. Any error must be visible. Use NSOpenPanel/NSSavePanel for backup; confirmation before replacement import. Avoid external dependencies.

## Validation ownership
C builds meaningful XCTest cases against public API and dates, persistence (temporary disk), goal nullification, backup validation, recurrence dedup. Lead compiles and launches actual app. C must distinguish executed results from checklist. No Xcode currently selected; Command Line Tools Swift is available, Lead investigates native build fallback.
