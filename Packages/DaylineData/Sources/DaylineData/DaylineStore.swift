import Foundation
import SwiftData
import Observation
import DaylineCore

@MainActor @Observable public final class DaylineStore {
    public let container: ModelContainer
    private let context: ModelContext
    public var tasks: [DayTask] = []
    public var goals: [Goal] = []
    public var areas: [Area] = []
    public var ideas: [Idea] = []
    public var planningEvents: [PlanningEventRecord] = []
    public var errorMessage: String?
    private var committedTasks: [UUID: TaskRecord] = [:]
    private var historySequence = 0
    private let automaticBackupDirectory: URL?

    public init(container: ModelContainer, automaticBackupDirectory: URL? = nil) throws {
        self.container = container
        self.automaticBackupDirectory = automaticBackupDirectory
        self.context = container.mainContext
        context.autosaveEnabled = false
        try refresh()
        if areas.isEmpty && goals.isEmpty && tasks.isEmpty {
            for seed in DaylineSeeds.areas {
                context.insert(Area(id: seed.id, name: seed.name, symbol: seed.symbol, colorKey: seed.colorKey, sortOrder: seed.sortOrder))
            }
            try context.save()
            try refresh()
        }
        try snapshot().validate()
        committedTasks = try taskSnapshot()
        try establishHistoryBaseline()
        runDailyBackup()
    }

    /// Local SwiftData container. Views and planning rules do not choose a sync backend.
    /// `cloudKitDatabase` stays `.none` until a separate schema upgrade. Passing no URL on
    /// macOS still opens `~/Library/Application Support/Dayline/Dayline.store`. iOS must pass
    /// its own sandbox URL and must never pass that Mac path.
    public static func makeContainer(inMemory: Bool = false, url: URL? = nil) throws -> ModelContainer {
        let schema = Schema([Area.self, Goal.self, DayTask.self, Idea.self, PlanningEventEntity.self])
        let configuration: ModelConfiguration
        if inMemory {
            configuration = ModelConfiguration("Dayline", schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        } else {
            let location: URL
            if let url {
                guard url.isFileURL else { throw DaylineDataError.invalid("数据库地址必须是本地文件。") }
                location = url
            } else {
                location = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                       appropriateFor: nil, create: true)
                    .appendingPathComponent("Dayline", isDirectory: true).appendingPathComponent("Dayline.store")
            }
            try FileManager.default.createDirectory(at: location.deletingLastPathComponent(), withIntermediateDirectories: true)
            try DaylineSafetyBackup.beforeUpgrade(at: location)
            configuration = ModelConfiguration("Dayline", schema: schema, url: location, allowsSave: true, cloudKitDatabase: .none)
        }
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    public func refresh() throws {
        // Publish only once all fetches have succeeded, keeping a coherent UI on read failure.
        let newAreas = try context.fetch(FetchDescriptor<Area>()).sorted {
            $0.sortOrder == $1.sortOrder ? $0.id.uuidString < $1.id.uuidString : $0.sortOrder < $1.sortOrder
        }
        let newGoals = try context.fetch(FetchDescriptor<Goal>()).sorted {
            $0.createdAt == $1.createdAt ? $0.id.uuidString < $1.id.uuidString : $0.createdAt < $1.createdAt
        }
        let newTasks = try context.fetch(FetchDescriptor<DayTask>()).sorted {
            if $0.sortOrder != $1.sortOrder { return $0.sortOrder < $1.sortOrder }
            if $0.createdAt != $1.createdAt { return $0.createdAt < $1.createdAt }
            return $0.id.uuidString < $1.id.uuidString
        }
        let newIdeas = try context.fetch(FetchDescriptor<Idea>()).sorted { $0.updatedAt > $1.updatedAt }
        let entities = try context.fetch(FetchDescriptor<PlanningEventEntity>()).sorted { $0.sequence < $1.sequence }
        let newEvents = try entities.map { try $0.record() }
        historySequence = entities.last?.sequence ?? 0
        areas = newAreas; goals = newGoals; tasks = newTasks
        ideas = newIdeas; planningEvents = newEvents
    }

    public func save() {
        do { try commit() } catch { reportAndRollback(error) }
    }

    @discardableResult
    public func addTask(title: String, areaID: UUID? = nil, scheduledDate: Date? = nil, dueDate: Date? = nil,
                 goalID: UUID? = nil, notes: String = "", priority: TaskPriority = .none,
                 repeatRule: RepeatRule = .none) -> DayTask? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { errorMessage = "请输入任务标题。"; return nil }
        var resolvedArea = areaID
        if let goalID {
            guard let goal = goals.first(where: { $0.id == goalID }) else { errorMessage = "所选目标已不存在。"; return nil }
            if resolvedArea == nil { resolvedArea = goal.areaID }
            if let goalArea = goal.areaID, resolvedArea != goalArea { errorMessage = "任务的领域必须与目标一致。"; return nil }
        }
        guard resolvedArea == nil || areas.contains(where: { $0.id == resolvedArea }) else {
            errorMessage = "所选领域已不存在。"; return nil
        }
        let task = DayTask(title: trimmed, notes: notes, areaID: resolvedArea, scheduledDate: scheduledDate,
                           dueDate: dueDate, goalID: goalID, priority: priority, sortOrder: nextSortOrder,
                           repeatRule: repeatRule)
        context.insert(task)
        do { try commit(); return task } catch { reportAndRollback(error); return nil }
    }

    public func toggleTask(_ task: DayTask) {
        guard owns(task) else { return }
        task.isCompleted.toggle()
        task.completedAt = task.isCompleted ? Date() : nil
        if task.isCompleted { makeSuccessorIfNeeded(for: task) }
        save()
    }

    public func deleteTask(_ task: DayTask) {
        guard owns(task) else { return }
        context.delete(task)
        // Predecessor successor IDs intentionally survive as deletion tombstones.
        save()
    }

    public func reschedule(_ task: DayTask, to date: Date?) {
        guard owns(task) else { return }
        task.scheduledDate = date.map { Calendar.current.startOfDay(for: $0) }
        save()
    }

    public func reorderTasks(_ orderedIDs: [UUID]) {
        guard Set(orderedIDs).count == orderedIDs.count,
              orderedIDs.allSatisfy({ id in tasks.contains { $0.id == id } }) else {
            errorMessage = "排序包含重复或不存在的任务。"; return
        }
        let selected = Set(orderedIDs)
        let taskMap = Dictionary(uniqueKeysWithValues: tasks.map { ($0.id, $0) })
        var cursor = 0
        let reordered = tasks.map { task -> DayTask in
            guard selected.contains(task.id) else { return task }
            defer { cursor += 1 }
            return taskMap[orderedIDs[cursor]]!
        }
        for (index, task) in reordered.enumerated() { task.sortOrder = Double(index) }
        save()
    }

    @discardableResult
    public func addGoal(title: String, kind: GoalKind, areaID: UUID?, parentGoalID: UUID? = nil,
                 notes: String = "", targetDate: Date? = nil, progress: Double = 0,
                 status: GoalStatus = .active) -> Goal? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { errorMessage = "请输入目标标题。"; return nil }
        var resolvedArea = areaID
        if let parentGoalID {
            guard kind == .shortTerm else { errorMessage = "长期目标不能有父目标。"; return nil }
            guard let parent = goals.first(where: { $0.id == parentGoalID }) else { errorMessage = "父目标已不存在。"; return nil }
            guard parent.kind == .longTerm else { errorMessage = "短期目标只能归属于长期目标。"; return nil }
            if resolvedArea == nil { resolvedArea = parent.areaID }
            if let parentArea = parent.areaID, resolvedArea != parentArea { errorMessage = "子目标的领域必须与父目标一致。"; return nil }
        }
        guard resolvedArea == nil || areas.contains(where: { $0.id == resolvedArea }) else {
            errorMessage = "所选领域已不存在。"; return nil
        }
        let goal = Goal(title: trimmed, notes: notes, kind: kind, status: status, targetDate: targetDate,
                        progress: status == .completed ? 1 : progress, areaID: resolvedArea, parentGoalID: parentGoalID)
        context.insert(goal)
        do { try commit(); return goal } catch { reportAndRollback(error); return nil }
    }

    public func deleteGoal(_ goal: Goal) {
        guard goals.contains(where: { $0 === goal }) else { errorMessage = "该目标已不在当前数据库中。"; return }
        for task in tasks where task.goalID == goal.id { task.goalID = nil }
        for idea in ideas where idea.goalID == goal.id { idea.goalID = nil }
        for child in goals where child.parentGoalID == goal.id { child.parentGoalID = nil }
        context.delete(goal)
        save()
    }

    public func setGoalStatus(_ goal: Goal, to status: GoalStatus) {
        guard goals.contains(where: { $0 === goal }) else { errorMessage = "该目标已不在当前数据库中。"; return }
        goal.status = status
        // This is an explicit user outcome decision, independent of linked task counts.
        if status == .completed { goal.progress = 1 }
        save()
    }

    public func exportBackup() throws -> Data {
        let backup = try snapshot()
        try backup.validate()
        return try DaylineBackup.encoder().encode(backup)
    }

    public func restoreBackup(_ data: Data) throws {
        let backup: DaylineBackup
        do {
            guard data.count <= 100 * 1024 * 1024 else { throw DaylineDataError.invalid("备份文件超过 100 MB。") }
            backup = try DaylineBackup.decoder().decode(DaylineBackup.self, from: data)
            try backup.validate() // No writes, deletions, saves, or rollbacks before full validation.
        } catch {
            errorMessage = "恢复失败：\(error.localizedDescription)"
            throw error // Preserve even pending unsaved edits when a document is invalid.
        }
        do {
            try commit() // Preserve any valid pending edits before the replacement transaction.
            try writeAutomaticBackup(name: "Before-Restore-\(UUID().uuidString).json")
            try context.transaction {
                let areaMap = Dictionary(uniqueKeysWithValues: areas.map { ($0.id, $0) })
                let goalMap = Dictionary(uniqueKeysWithValues: goals.map { ($0.id, $0) })
                let taskMap = Dictionary(uniqueKeysWithValues: tasks.map { ($0.id, $0) })
                let ideaMap = Dictionary(uniqueKeysWithValues: ideas.map { ($0.id, $0) })
                let importedAreaIDs = Set(backup.areas.map(\.id))
                let importedGoalIDs = Set(backup.goals.map(\.id))
                let importedTaskIDs = Set(backup.tasks.map(\.id))
                let importedIdeaIDs = Set(backup.ideas.map(\.id))
                for idea in ideas where !importedIdeaIDs.contains(idea.id) { context.delete(idea) }
                for event in try context.fetch(FetchDescriptor<PlanningEventEntity>()) { context.delete(event) }
                for task in tasks where !importedTaskIDs.contains(task.id) { context.delete(task) }
                for goal in goals where !importedGoalIDs.contains(goal.id) { context.delete(goal) }
                for area in areas where !importedAreaIDs.contains(area.id) { context.delete(area) }
                for record in backup.areas {
                    if let model = areaMap[record.id] { record.apply(to: model) } else { context.insert(record.model()) }
                }
                for record in backup.goals {
                    if let model = goalMap[record.id] { record.apply(to: model) } else { context.insert(record.model()) }
                }
                for record in backup.tasks {
                    if let model = taskMap[record.id] { record.apply(to: model) } else { context.insert(record.model()) }
                }
                for record in backup.ideas {
                    if let model = ideaMap[record.id] { record.apply(to: model) } else { context.insert(record.model()) }
                }
                for (index, record) in backup.planningEvents.enumerated() { context.insert(try PlanningEventEntity(record, sequence: index + 1)) }
                try context.save()
            }
            try refresh()
            committedTasks = try taskSnapshot()
            try establishHistoryBaseline()
            errorMessage = nil
        } catch {
            // Invalid documents never reached mutation; transaction/save failures roll back
            // to the last durable state instead of leaving a half-restored main context.
            if context.hasChanges { context.rollback() }
            try? refresh()
            errorMessage = "恢复失败：\(error.localizedDescription)"
            throw error
        }
    }

    public func loadDemoData() {
        let learning = DaylineSeeds.areas[0].id
        let research = DaylineSeeds.areas[1].id
        let health = DaylineSeeds.areas[2].id
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let longID = UUID(uuidString: "D3110000-0000-4000-8000-000000000001")!
        let shortID = UUID(uuidString: "D3110000-0000-4000-8000-000000000002")!
        if !goals.contains(where: { $0.id == longID }) {
            context.insert(Goal(id: longID, title: "建立扎实的研究方法", notes: "示例目标，可自由编辑或删除。", kind: .longTerm, progress: 0.25, areaID: research))
        }
        if !goals.contains(where: { $0.id == shortID }) {
            context.insert(Goal(id: shortID, title: "完成第一轮文献整理", kind: .shortTerm, targetDate: calendar.date(byAdding: .day, value: 14, to: today), progress: 0.4, areaID: research, parentGoalID: longID))
        }
        let samples: [(String, String, UUID?, UUID?, Date?, Date?, RepeatRule)] = [
            ("D3110000-0000-4000-8000-000000000101", "阅读 20 分钟", learning, nil, today, nil, .daily),
            ("D3110000-0000-4000-8000-000000000102", "整理两篇论文的核心发现", research, shortID, today, today, .none),
            ("D3110000-0000-4000-8000-000000000103", "散步，给大脑留一点空白", health, nil, today, nil, .none),
            ("D3110000-0000-4000-8000-000000000104", "一个还没想清楚的灵感", nil, nil, nil, nil, .none),
            ("D3110000-0000-4000-8000-000000000105", "安排下周的学习时间", learning, nil, calendar.date(byAdding: .day, value: 2, to: today), nil, .none),
            ("D3110000-0000-4000-8000-000000000106", "继续昨天的笔记", learning, nil, calendar.date(byAdding: .day, value: -1, to: today), nil, .none)
        ]
        for (index, sample) in samples.enumerated() {
            let id = UUID(uuidString: sample.0)!
            guard !tasks.contains(where: { $0.id == id }) else { continue }
            context.insert(DayTask(id: id, title: sample.1, notes: "示例任务", areaID: sample.2,
                                   scheduledDate: sample.4, dueDate: sample.5, goalID: sample.3,
                                   sortOrder: nextSortOrder + Double(index), repeatRule: sample.6))
        }
        save()
    }

    @discardableResult
    public func addIdea(title: String = "新灵感", body: String = "", areaID: UUID? = nil, goalID: UUID? = nil) -> Idea? {
        let idea = Idea(title: title, body: body, areaID: areaID, goalID: goalID)
        context.insert(idea)
        do { try commit(); return idea } catch { reportAndRollback(error); return nil }
    }

    public func updateIdea(_ idea: Idea, title: String, body: String, areaID: UUID?, goalID: UUID?) {
        guard ideas.contains(where: { $0 === idea }) else { return }
        idea.title = title; idea.body = body; idea.areaID = areaID; idea.goalID = goalID
        idea.updatedAt = Date()
        save()
    }
    public func setIdeaPinned(_ idea: Idea, to value: Bool) {
        guard ideas.contains(where: { $0 === idea }) else { return }
        idea.isPinned = value; idea.updatedAt = Date(); save()
    }
    public func setIdeaArchived(_ idea: Idea, to value: Bool) {
        guard ideas.contains(where: { $0 === idea }) else { return }
        idea.isArchived = value; idea.updatedAt = Date(); save()
    }
    public func deleteIdea(_ idea: Idea) {
        guard ideas.contains(where: { $0 === idea }) else { return }
        context.delete(idea); save()
    }
    @discardableResult
    public func taskFromIdea(_ idea: Idea) -> DayTask? {
        let title = idea.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return addTask(title: title.isEmpty ? "未命名灵感" : title, areaID: idea.areaID, goalID: idea.goalID, notes: idea.body)
    }

    public func runDailyBackup() {
        guard automaticBackupDirectory != nil else { return }
        do { try writeAutomaticBackup(name: "Dayline-Auto-\(Self.historyDay(Date())).json") }
        catch { errorMessage = "自动备份失败：\(error.localizedDescription)" }
    }
    private func writeAutomaticBackup(name: String) throws {
        guard let directory = automaticBackupDirectory else { return }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(name)
        guard !FileManager.default.fileExists(atPath: url.path) else { return }
        let temporary = directory.appendingPathComponent(".\(UUID().uuidString).partial")
        defer { try? FileManager.default.removeItem(at: temporary) }
        try exportBackup().write(to: temporary, options: .withoutOverwriting)
        try FileManager.default.moveItem(at: temporary, to: url)
    }
    private func taskSnapshot() throws -> [UUID: TaskRecord] {
        Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<DayTask>()).map { ($0.id, try TaskRecord($0)) })
    }
    private static func historyDay(_ date: Date) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian); f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current; f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
    private func historyEvent(_ task: TaskRecord, kind: PlanningEventKind, day: String?, newDay: String? = nil, at date: Date = Date()) throws {
        let record = PlanningEventRecord(taskID: task.id, kind: kind, occurredAt: date,
                                        dayKey: day,
                                        newDayKey: newDay, timeZoneID: TimeZone.current.identifier,
                                        taskTitle: task.title, areaID: task.areaID,
                                        recurrenceSourceID: task.recurrenceSourceID,
                                        occurrenceDate: task.recurrenceOccurrenceDate,
                                        wasCompleted: task.isCompleted)
        historySequence += 1
        context.insert(try PlanningEventEntity(record, sequence: historySequence))
    }
    private func establishHistoryBaseline() throws {
        let observed = Set(planningEvents.map(\.taskID))
        for task in committedTasks.values where !observed.contains(task.id) {
            try historyEvent(task, kind: .baseline, day: (task.scheduledDate ?? task.dueDate).map(Self.historyDay))
        }
        if context.hasChanges { try context.save(); try refresh() }
    }
    private func recordTaskChanges() throws {
        // A plan belongs to its captured calendar day even after the user changes time zone.
        // The wrapper distinguishes an explicitly unscheduled task from missing history.
        struct Assignment { let dayKey: String? }
        var assignments: [UUID: Assignment] = [:]
        for event in planningEvents {
            switch event.kind {
            case .baseline, .planned: assignments[event.taskID] = Assignment(dayKey: event.dayKey)
            case .rescheduled: assignments[event.taskID] = Assignment(dayKey: event.newDayKey)
            case .deleted: assignments[event.taskID] = nil
            case .completed, .reopened: break
            }
        }
        func assignedDay(_ task: TaskRecord) -> String? {
            if let assignment = assignments[task.id] { return assignment.dayKey }
            return (task.scheduledDate ?? task.dueDate).map(Self.historyDay)
        }
        let current = try taskSnapshot()
        for task in current.values {
            guard let old = committedTasks[task.id] else {
                let day = (task.scheduledDate ?? task.dueDate).map(Self.historyDay)
                try historyEvent(task, kind: .planned, day: day)
                assignments[task.id] = Assignment(dayKey: day)
                continue
            }
            // Compare both snapshots in the action's zone to detect a real date edit,
            // rather than treating travel alone as a reschedule.
            let oldDay = (old.scheduledDate ?? old.dueDate).map(Self.historyDay)
            let newDay = (task.scheduledDate ?? task.dueDate).map(Self.historyDay)
            if oldDay != newDay {
                try historyEvent(old, kind: .rescheduled, day: assignedDay(old), newDay: newDay)
                assignments[task.id] = Assignment(dayKey: newDay)
            }
            if old.isCompleted != task.isCompleted {
                try historyEvent(task, kind: task.isCompleted ? .completed : .reopened, day: assignedDay(task))
            }
        }
        for old in committedTasks.values where current[old.id] == nil {
            try historyEvent(old, kind: .deleted, day: assignedDay(old))
            assignments[old.id] = nil
        }
    }

    private var nextSortOrder: Double { (tasks.map(\.sortOrder).max() ?? -1) + 1 }

    private func owns(_ task: DayTask) -> Bool {
        guard tasks.contains(where: { $0 === task }) else { errorMessage = "该任务已不在当前数据库中。"; return false }
        return true
    }

    private func snapshot() throws -> DaylineBackup {
        // Fetch includes pending insertions and excludes pending deletions, unlike published arrays.
        let records = DaylineBackup(areas: try context.fetch(FetchDescriptor<Area>()).map(AreaRecord.init),
                                    goals: try context.fetch(FetchDescriptor<Goal>()).map(GoalRecord.init),
                                    tasks: try context.fetch(FetchDescriptor<DayTask>()).map(TaskRecord.init),
                                    ideas: try context.fetch(FetchDescriptor<Idea>()).map(IdeaRecord.init),
                                    planningEvents: try context.fetch(FetchDescriptor<PlanningEventEntity>()).sorted { $0.sequence < $1.sequence }.map { try $0.record() })
        return records
    }

    private func commit() throws {
        try snapshot().validate()
        try recordTaskChanges()
        try context.save()
        try refresh()
        committedTasks = try taskSnapshot()
        errorMessage = nil
    }

    private func reportAndRollback(_ error: Error) {
        context.rollback()
        try? refresh()
        errorMessage = "未能保存：\(error.localizedDescription)"
    }

    private func makeSuccessorIfNeeded(for task: DayTask) {
        guard task.repeatRule != .none, task.recurrenceSuccessorID == nil else { return }
        let calendar = Calendar.current
        let anchor = task.scheduledDate ?? task.dueDate ?? task.recurrenceOccurrenceDate ?? Date()
        // An occurrence's identity date never moves. Rescheduling earlier must not create
        // a successor that predates that identity or collides with an existing occurrence.
        let recurrenceAnchor = max(anchor, task.recurrenceOccurrenceDate ?? anchor)
        guard let date = DaylineDates.nextOccurrence(after: recurrenceAnchor, rule: task.repeatRule, calendar: calendar) else { return }
        let source = task.recurrenceSourceID ?? task.id
        task.recurrenceSourceID = source
        task.recurrenceOccurrenceDate = task.recurrenceOccurrenceDate ?? calendar.startOfDay(for: anchor)
        let id = DaylineIdentity.recurrenceSuccessorID(source: source, occurrence: date, calendar: calendar)
        if let existing = tasks.first(where: { $0.id == id || ($0.recurrenceSourceID == source && $0.recurrenceOccurrenceDate == date) }) {
            task.recurrenceSuccessorID = existing.id
            return
        }
        task.recurrenceSuccessorID = id
        // Preserve the relative due-day offset when a task has both a schedule and a deadline.
        var nextDue: Date?
        if let due = task.dueDate {
            let offset = calendar.dateComponents([.day], from: calendar.startOfDay(for: anchor), to: calendar.startOfDay(for: due)).day ?? 0
            nextDue = calendar.date(byAdding: .day, value: offset, to: date)
        }
        let successor = DayTask(id: id, title: task.title, notes: task.notes, areaID: task.areaID,
                                scheduledDate: task.scheduledDate != nil || task.dueDate == nil ? date : nil,
                                dueDate: nextDue, goalID: task.goalID, priority: task.priority,
                                sortOrder: nextSortOrder, repeatRule: task.repeatRule,
                                recurrenceSourceID: source, recurrenceOccurrenceDate: date)
        context.insert(successor)
    }
}

public extension AreaRecord {
    func apply(to area: Area) {
        area.name = name; area.symbol = symbol; area.colorKey = colorKey; area.sortOrder = sortOrder
    }
}
public extension GoalRecord {
    func apply(to goal: Goal) {
        goal.title = title; goal.notes = notes; goal.kind = kind; goal.status = status
        goal.targetDate = targetDate; goal.progress = progress; goal.areaID = areaID
        goal.parentGoalID = parentGoalID; goal.createdAt = createdAt
    }
}
public extension TaskRecord {
    func apply(to task: DayTask) {
        task.title = title; task.notes = notes; task.areaID = areaID; task.goalID = goalID
        task.scheduledDate = scheduledDate; task.dueDate = dueDate; task.isCompleted = isCompleted
        task.completedAt = completedAt; task.priority = priority; task.sortOrder = sortOrder
        task.repeatRule = repeatRule; task.createdAt = createdAt; task.recurrenceSourceID = recurrenceSourceID
        task.recurrenceOccurrenceDate = recurrenceOccurrenceDate; task.recurrenceSuccessorID = recurrenceSuccessorID
    }
}
