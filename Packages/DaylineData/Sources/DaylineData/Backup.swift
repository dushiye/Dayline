import Foundation
import DaylineCore

public enum DaylineDataError: LocalizedError {
    case invalid(String)
    public var errorDescription: String? {
        switch self { case .invalid(let message): return message }
    }
}

public struct DaylineBackup: Codable {
    public var schemaVersion: Int = 3
    public var exportedAt: Date = Date()
    public var areas: [AreaRecord]
    public var goals: [GoalRecord]
    public var tasks: [TaskRecord]
    public var ideas: [IdeaRecord] = []
    public var planningEvents: [PlanningEventRecord] = []
    public var dailyReviews: [DailyReviewRecord] = []

    public init(schemaVersion: Int = 3, exportedAt: Date = Date(), areas: [AreaRecord], goals: [GoalRecord],
         tasks: [TaskRecord], ideas: [IdeaRecord] = [], planningEvents: [PlanningEventRecord] = [],
         dailyReviews: [DailyReviewRecord] = []) {
        self.schemaVersion = schemaVersion; self.exportedAt = exportedAt
        self.areas = areas; self.goals = goals; self.tasks = tasks
        self.ideas = ideas; self.planningEvents = planningEvents; self.dailyReviews = dailyReviews
    }
    enum CodingKeys: String, CodingKey { case schemaVersion, exportedAt, areas, goals, tasks, ideas, planningEvents, dailyReviews }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try c.decode(Int.self, forKey: .schemaVersion)
        exportedAt = try c.decode(Date.self, forKey: .exportedAt)
        areas = try c.decode([AreaRecord].self, forKey: .areas)
        goals = try c.decode([GoalRecord].self, forKey: .goals)
        tasks = try c.decode([TaskRecord].self, forKey: .tasks)
        if schemaVersion == 1 {
            ideas = try c.decodeIfPresent([IdeaRecord].self, forKey: .ideas) ?? []
            planningEvents = try c.decodeIfPresent([PlanningEventRecord].self, forKey: .planningEvents) ?? []
            dailyReviews = try c.decodeIfPresent([DailyReviewRecord].self, forKey: .dailyReviews) ?? []
        } else if schemaVersion == 2 {
            ideas = try c.decode([IdeaRecord].self, forKey: .ideas)
            planningEvents = try c.decode([PlanningEventRecord].self, forKey: .planningEvents)
            dailyReviews = try c.decodeIfPresent([DailyReviewRecord].self, forKey: .dailyReviews) ?? []
        } else {
            ideas = try c.decode([IdeaRecord].self, forKey: .ideas)
            planningEvents = try c.decode([PlanningEventRecord].self, forKey: .planningEvents)
            dailyReviews = try c.decode([DailyReviewRecord].self, forKey: .dailyReviews)
        }
    }

    public static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    public static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return decoder
    }

    public func validate() throws {
        func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
            if !condition() { throw DaylineDataError.invalid(message) }
        }
        func validDate(_ date: Date?) -> Bool {
            guard let date else { return true }
            // Calendar arithmetic is intentionally limited to the Gregorian years 0001–9999.
            return date.timeIntervalSince1970.isFinite
                && (-62_135_596_800...253_402_300_799).contains(date.timeIntervalSince1970)
        }
        try require((1...3).contains(schemaVersion), "不支持的备份版本：\(schemaVersion)。")
        try require(schemaVersion != 1 || (ideas.isEmpty && planningEvents.isEmpty), "旧版备份不能包含新版记录。")
        try require(schemaVersion == 3 || dailyReviews.isEmpty, "旧版备份不能包含每日回顾。")
        try require(validDate(exportedAt), "备份导出时间无效。")
        try require(areas.count <= 100 && goals.count <= 100_000 && tasks.count <= 100_000, "备份中的记录数量过大。")
        try require(ideas.count <= 100_000 && planningEvents.count <= 1_000_000 && dailyReviews.count <= 100_000,
                    "灵感、历史记录或每日回顾数量过大。")
        let allIDs = areas.map(\.id) + goals.map(\.id) + tasks.map(\.id) + ideas.map(\.id)
            + planningEvents.map(\.id) + dailyReviews.map(\.id)
        try require(Set(allIDs).count == allIDs.count, "备份包含重复 ID。")
        let areaIDs = Set(areas.map(\.id))
        let goalMap = Dictionary(uniqueKeysWithValues: goals.map { ($0.id, $0) })
        let taskMap = Dictionary(uniqueKeysWithValues: tasks.map { ($0.id, $0) })
        for idea in ideas {
            try require(validDate(idea.createdAt) && validDate(idea.updatedAt), "灵感日期无效。")
            if let area = idea.areaID { try require(areaIDs.contains(area), "灵感引用了不存在的领域。") }
            if let goalID = idea.goalID { try require(goalMap[goalID] != nil, "灵感引用了不存在的目标。") }
        }
        for event in planningEvents {
            try require(validDate(event.occurredAt) && validDate(event.occurrenceDate), "计划历史时间无效。")
            try require(TimeZone(identifier: event.timeZoneID) != nil, "计划历史时区无效。")
            for key in [event.dayKey, event.newDayKey].compactMap({ $0 }) {
                let formatter = DateFormatter()
                formatter.calendar = Calendar(identifier: .gregorian)
                formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.timeZone = TimeZone(secondsFromGMT: 0)
                formatter.dateFormat = "yyyy-MM-dd"; formatter.isLenient = false
                try require(key.count == 10 && formatter.date(from: key).map { formatter.string(from: $0) == key } == true, "计划历史日期无效。")
            }
            // Historical task/area IDs are intentionally retained after deletion.
        }
        var reviewDays = Set<String>()
        for review in dailyReviews {
            try require(DailyReviewDay.isValid(review.dayKey), "每日回顾日期无效。")
            try require(TimeZone(identifier: review.timeZoneID) != nil, "每日回顾时区无效。")
            try require(validDate(review.createdAt) && validDate(review.updatedAt) && review.updatedAt >= review.createdAt,
                        "每日回顾时间无效。")
            try require(review.id == DailyReviewDay.stableID(for: review.dayKey), "每日回顾身份与日期不匹配。")
            try require(reviewDays.insert(review.dayKey).inserted, "同一天包含多条每日回顾。")
            try require([review.learned, review.growth, review.nextStep, review.freeformNotes].contains {
                !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }, "每日回顾不能完全为空。")
            try require([review.learned, review.growth, review.nextStep, review.freeformNotes].allSatisfy { $0.count <= 1_000_000 },
                        "每日回顾文本过长。")
        }
        try require(areas.count == DaylineSeeds.areas.count, "必须保留 Learning、Research 和 Health 三个领域。")
        for seed in DaylineSeeds.areas {
            try require(areas.contains { $0.id == seed.id && $0.name == seed.name }, "领域 ID 或名称与当前版本不匹配。")
        }
        for area in areas {
            try require(!area.symbol.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "领域图标不能为空。")
            try require(["blue", "purple", "green"].contains(area.colorKey), "领域颜色无效。")
        }
        for goal in goals {
            try require(!goal.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "目标标题不能为空。")
            try require(goal.progress.isFinite && (0...1).contains(goal.progress), "目标进度必须介于 0 与 1 之间。")
            try require(validDate(goal.createdAt) && validDate(goal.targetDate), "目标日期无效。")
            if let area = goal.areaID { try require(areaIDs.contains(area), "目标引用了不存在的领域。") }
            if goal.kind == .longTerm { try require(goal.parentGoalID == nil, "长期目标不能有父目标。") }
            if let parentID = goal.parentGoalID {
                guard let parent = goalMap[parentID] else { throw DaylineDataError.invalid("目标引用了不存在的父目标。") }
                try require(parentID != goal.id, "目标不能以自身为父目标。")
                try require(parent.kind == .longTerm && goal.kind == .shortTerm, "短期目标只能归属于长期目标。")
                if let parentArea = parent.areaID { try require(goal.areaID == parentArea, "子目标的领域必须与父目标一致。") }
            }
        }
        // Iterative color walk avoids recursion limits on deeply nested imported hierarchies.
        var verified = Set<UUID>()
        for goal in goals where !verified.contains(goal.id) {
            var visiting = Set<UUID>()
            var cursor: UUID? = goal.id
            while let id = cursor, !verified.contains(id) {
                try require(visiting.insert(id).inserted, "目标层级包含循环引用。")
                cursor = goalMap[id]?.parentGoalID
            }
            verified.formUnion(visiting)
        }
        var occurrences = Set<String>()
        for task in tasks {
            try require(!task.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "任务标题不能为空。")
            try require(task.sortOrder.isFinite, "任务排序值无效。")
            try require(validDate(task.scheduledDate) && validDate(task.dueDate) && validDate(task.completedAt)
                        && validDate(task.createdAt) && validDate(task.recurrenceOccurrenceDate), "任务日期无效。")
            try require(task.isCompleted == (task.completedAt != nil), "任务完成状态与完成时间不一致。")
            if let area = task.areaID { try require(areaIDs.contains(area), "任务引用了不存在的领域。") }
            if let goalID = task.goalID {
                guard let goal = goalMap[goalID] else { throw DaylineDataError.invalid("任务引用了不存在的目标。") }
                if let goalArea = goal.areaID { try require(task.areaID == goalArea, "任务的领域必须与目标一致。") }
            }
            try require((task.recurrenceSourceID == nil) == (task.recurrenceOccurrenceDate == nil), "重复任务的系列信息不完整。")
            if let source = task.recurrenceSourceID, let occurrence = task.recurrenceOccurrenceDate {
                let key = "\(source.uuidString):\(occurrence.timeIntervalSince1970)"
                try require(occurrences.insert(key).inserted, "重复任务包含重复的发生日期。")
                if let sourceTask = taskMap[source] {
                    try require(sourceTask.recurrenceSourceID == source, "重复任务的系列引用无效。")
                }
            }
            if let successorID = task.recurrenceSuccessorID {
                try require(successorID != task.id && task.recurrenceSourceID != nil, "重复任务的后继引用无效。")
                // A missing successor is an intentional tombstone after deletion.
                if let successor = taskMap[successorID] {
                    try require(successor.recurrenceSourceID == task.recurrenceSourceID, "重复任务的后继属于其他系列。")
                    if let date = task.recurrenceOccurrenceDate, let nextDate = successor.recurrenceOccurrenceDate {
                        try require(nextDate > date, "重复任务的后继日期必须晚于当前日期。")
                    }
                }
            }
        }
    }
}

public struct AreaRecord: Codable {
    public var id: UUID; public var name: String; public var symbol: String; public var colorKey: String; public var sortOrder: Int
    public init(_ area: Area) {
        id = area.id; name = area.name; symbol = area.symbol; colorKey = area.colorKey; sortOrder = area.sortOrder
    }
    public func model() -> Area { Area(id: id, name: name, symbol: symbol, colorKey: colorKey, sortOrder: sortOrder) }
}

public struct GoalRecord: Codable {
    public var id: UUID; public var title: String; public var notes: String; public var kind: GoalKind; public var status: GoalStatus
    public var targetDate: Date?; public var progress: Double; public var areaID: UUID?; public var parentGoalID: UUID?; public var createdAt: Date
    public init(_ goal: Goal) throws {
        guard let kind = GoalKind(rawValue: goal.kindRaw), let status = GoalStatus(rawValue: goal.statusRaw) else {
            throw DaylineDataError.invalid("目标类型或状态无效。")
        }
        id = goal.id; title = goal.title; notes = goal.notes; self.kind = kind; self.status = status
        targetDate = goal.targetDate; progress = goal.progress; areaID = goal.areaID
        parentGoalID = goal.parentGoalID; createdAt = goal.createdAt
    }
    public func model() -> Goal {
        Goal(id: id, title: title, notes: notes, kind: kind, status: status, targetDate: targetDate,
             progress: progress, areaID: areaID, parentGoalID: parentGoalID, createdAt: createdAt)
    }
}

public struct TaskRecord: Codable {
    public var id: UUID; public var title: String; public var notes: String; public var areaID: UUID?; public var goalID: UUID?
    public var scheduledDate: Date?; public var dueDate: Date?; public var isCompleted: Bool; public var completedAt: Date?
    public var priority: TaskPriority; public var sortOrder: Double; public var repeatRule: RepeatRule; public var createdAt: Date
    public var recurrenceSourceID: UUID?; public var recurrenceOccurrenceDate: Date?; public var recurrenceSuccessorID: UUID?
    public init(_ task: DayTask) throws {
        guard let priority = TaskPriority(rawValue: task.priorityRaw), let rule = RepeatRule(rawValue: task.repeatRuleRaw) else {
            throw DaylineDataError.invalid("任务优先级或重复规则无效。")
        }
        id = task.id; title = task.title; notes = task.notes; areaID = task.areaID; goalID = task.goalID
        scheduledDate = task.scheduledDate; dueDate = task.dueDate; isCompleted = task.isCompleted
        completedAt = task.completedAt; self.priority = priority; sortOrder = task.sortOrder
        repeatRule = rule; createdAt = task.createdAt; recurrenceSourceID = task.recurrenceSourceID
        recurrenceOccurrenceDate = task.recurrenceOccurrenceDate; recurrenceSuccessorID = task.recurrenceSuccessorID
    }
    public func model() -> DayTask {
        DayTask(id: id, title: title, notes: notes, areaID: areaID, scheduledDate: scheduledDate,
                dueDate: dueDate, goalID: goalID, isCompleted: isCompleted, completedAt: completedAt,
                priority: priority, sortOrder: sortOrder, repeatRule: repeatRule, createdAt: createdAt,
                recurrenceSourceID: recurrenceSourceID, recurrenceOccurrenceDate: recurrenceOccurrenceDate,
                recurrenceSuccessorID: recurrenceSuccessorID)
    }
}

public enum DaylineSeeds {
    static let areas: [(id: UUID, name: String, symbol: String, colorKey: String, sortOrder: Int)] = [
        (UUID(uuidString: "6BD2196D-CEEA-443E-B134-000000000001")!, "Learning", "book.closed", "blue", 0),
        (UUID(uuidString: "6BD2196D-CEEA-443E-B134-000000000002")!, "Research", "sparkle.magnifyingglass", "purple", 1),
        (UUID(uuidString: "6BD2196D-CEEA-443E-B134-000000000003")!, "Health", "heart", "green", 2)
    ]
}
