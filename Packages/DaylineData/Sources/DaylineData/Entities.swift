import Foundation
import SwiftData
import Observation
import DaylineCore

public final class Area: PersistentModel {
    private var _$backingData: any BackingData<Area> = Area.createBackingData()
    public var persistentBackingData: any BackingData<Area> {
        get { _$backingData }
        set { _$backingData = newValue }
    }
    private let _$observationRegistrar = ObservationRegistrar()
    public required init(backingData: any BackingData<Area>) { persistentBackingData = backingData }
    public static var schemaMetadata: [Schema.PropertyMetadata] {
        [
            .init(name: "id", keypath: \Area.id, defaultValue: nil, metadata: Schema.Attribute(.unique)),
            .init(name: "name", keypath: \Area.name, defaultValue: "", metadata: nil),
            .init(name: "symbol", keypath: \Area.symbol, defaultValue: "", metadata: nil),
            .init(name: "colorKey", keypath: \Area.colorKey, defaultValue: "", metadata: nil),
            .init(name: "sortOrder", keypath: \Area.sortOrder, defaultValue: 0, metadata: nil)
        ]
    }

    public var id: UUID {
        get { _$observationRegistrar.access(self, keyPath: \.id); return getValue(forKey: \.id) }
        set { _$observationRegistrar.withMutation(of: self, keyPath: \.id) { setValue(forKey: \.id, to: newValue) } }
    }
    public var name: String {
        get { _$observationRegistrar.access(self, keyPath: \.name); return getValue(forKey: \.name) }
        set { _$observationRegistrar.withMutation(of: self, keyPath: \.name) { setValue(forKey: \.name, to: newValue) } }
    }
    public var symbol: String {
        get { _$observationRegistrar.access(self, keyPath: \.symbol); return getValue(forKey: \.symbol) }
        set { _$observationRegistrar.withMutation(of: self, keyPath: \.symbol) { setValue(forKey: \.symbol, to: newValue) } }
    }
    public var colorKey: String {
        get { _$observationRegistrar.access(self, keyPath: \.colorKey); return getValue(forKey: \.colorKey) }
        set { _$observationRegistrar.withMutation(of: self, keyPath: \.colorKey) { setValue(forKey: \.colorKey, to: newValue) } }
    }
    public var sortOrder: Int {
        get { _$observationRegistrar.access(self, keyPath: \.sortOrder); return getValue(forKey: \.sortOrder) }
        set { _$observationRegistrar.withMutation(of: self, keyPath: \.sortOrder) { setValue(forKey: \.sortOrder, to: newValue) } }
    }

    public init(id: UUID = UUID(), name: String, symbol: String = "folder", colorKey: String = "blue", sortOrder: Int = 0) {
        self.id = id
        self.name = name
        self.symbol = symbol
        self.colorKey = colorKey
        self.sortOrder = sortOrder
    }
}

public final class Goal: PersistentModel {
    private var _$backingData: any BackingData<Goal> = Goal.createBackingData()
    public var persistentBackingData: any BackingData<Goal> {
        get { _$backingData }
        set { _$backingData = newValue }
    }
    private let _$observationRegistrar = ObservationRegistrar()
    public required init(backingData: any BackingData<Goal>) { persistentBackingData = backingData }
    public static var schemaMetadata: [Schema.PropertyMetadata] {
        [
            .init(name: "id", keypath: \Goal.id, defaultValue: nil, metadata: Schema.Attribute(.unique)),
            .init(name: "title", keypath: \Goal.title, defaultValue: "", metadata: nil),
            .init(name: "notes", keypath: \Goal.notes, defaultValue: "", metadata: nil),
            .init(name: "kindRaw", keypath: \Goal.kindRaw, defaultValue: "", metadata: nil),
            .init(name: "statusRaw", keypath: \Goal.statusRaw, defaultValue: "", metadata: nil),
            .init(name: "targetDate", keypath: \Goal.targetDate, defaultValue: nil, metadata: nil),
            .init(name: "progress", keypath: \Goal.progress, defaultValue: 0.0, metadata: nil),
            .init(name: "areaID", keypath: \Goal.areaID, defaultValue: nil, metadata: nil),
            .init(name: "parentGoalID", keypath: \Goal.parentGoalID, defaultValue: nil, metadata: nil),
            .init(name: "createdAt", keypath: \Goal.createdAt, defaultValue: Date(timeIntervalSince1970: 0), metadata: nil)
        ]
    }

    public var id: UUID {
        get { _$observationRegistrar.access(self, keyPath: \.id); return getValue(forKey: \.id) }
        set { _$observationRegistrar.withMutation(of: self, keyPath: \.id) { setValue(forKey: \.id, to: newValue) } }
    }
    public var title: String {
        get { _$observationRegistrar.access(self, keyPath: \.title); return getValue(forKey: \.title) }
        set { _$observationRegistrar.withMutation(of: self, keyPath: \.title) { setValue(forKey: \.title, to: newValue) } }
    }
    public var notes: String {
        get { _$observationRegistrar.access(self, keyPath: \.notes); return getValue(forKey: \.notes) }
        set { _$observationRegistrar.withMutation(of: self, keyPath: \.notes) { setValue(forKey: \.notes, to: newValue) } }
    }
    public var kindRaw: String {
        get { _$observationRegistrar.access(self, keyPath: \.kindRaw); return getValue(forKey: \.kindRaw) }
        set { _$observationRegistrar.withMutation(of: self, keyPath: \.kindRaw) { setValue(forKey: \.kindRaw, to: newValue) } }
    }
    public var statusRaw: String {
        get { _$observationRegistrar.access(self, keyPath: \.statusRaw); return getValue(forKey: \.statusRaw) }
        set { _$observationRegistrar.withMutation(of: self, keyPath: \.statusRaw) { setValue(forKey: \.statusRaw, to: newValue) } }
    }
    public var targetDate: Date? {
        get { _$observationRegistrar.access(self, keyPath: \.targetDate); return getValue(forKey: \.targetDate) }
        set { _$observationRegistrar.withMutation(of: self, keyPath: \.targetDate) { setValue(forKey: \.targetDate, to: newValue) } }
    }
    /// Explicit outcome progress; task completion never changes this value.
    public var progress: Double {
        get { _$observationRegistrar.access(self, keyPath: \.progress); return getValue(forKey: \.progress) }
        set { _$observationRegistrar.withMutation(of: self, keyPath: \.progress) { setValue(forKey: \.progress, to: newValue) } }
    }
    public var areaID: UUID? {
        get { _$observationRegistrar.access(self, keyPath: \.areaID); return getValue(forKey: \.areaID) }
        set { _$observationRegistrar.withMutation(of: self, keyPath: \.areaID) { setValue(forKey: \.areaID, to: newValue) } }
    }
    public var parentGoalID: UUID? {
        get { _$observationRegistrar.access(self, keyPath: \.parentGoalID); return getValue(forKey: \.parentGoalID) }
        set { _$observationRegistrar.withMutation(of: self, keyPath: \.parentGoalID) { setValue(forKey: \.parentGoalID, to: newValue) } }
    }
    public var createdAt: Date {
        get { _$observationRegistrar.access(self, keyPath: \.createdAt); return getValue(forKey: \.createdAt) }
        set { _$observationRegistrar.withMutation(of: self, keyPath: \.createdAt) { setValue(forKey: \.createdAt, to: newValue) } }
    }

    public var kind: GoalKind {
        get { GoalKind(rawValue: kindRaw) ?? .shortTerm }
        set { kindRaw = newValue.rawValue }
    }
    public var status: GoalStatus {
        get { GoalStatus(rawValue: statusRaw) ?? .active }
        set { statusRaw = newValue.rawValue }
    }

    public init(id: UUID = UUID(), title: String, notes: String = "", kind: GoalKind = .shortTerm,
         status: GoalStatus = .active, targetDate: Date? = nil, progress: Double = 0,
         areaID: UUID? = nil, parentGoalID: UUID? = nil, createdAt: Date = Date()) {
        self.id = id
        self.title = title
        self.notes = notes
        self.kindRaw = kind.rawValue
        self.statusRaw = status.rawValue
        self.targetDate = targetDate
        self.progress = progress
        self.areaID = areaID
        self.parentGoalID = parentGoalID
        self.createdAt = createdAt
    }
}

public final class DayTask: PersistentModel {
    private var _$backingData: any BackingData<DayTask> = DayTask.createBackingData()
    public var persistentBackingData: any BackingData<DayTask> {
        get { _$backingData }
        set { _$backingData = newValue }
    }
    private let _$observationRegistrar = ObservationRegistrar()
    public required init(backingData: any BackingData<DayTask>) { persistentBackingData = backingData }
    public static var schemaMetadata: [Schema.PropertyMetadata] {
        [
            .init(name: "id", keypath: \DayTask.id, defaultValue: nil, metadata: Schema.Attribute(.unique)),
            .init(name: "title", keypath: \DayTask.title, defaultValue: "", metadata: nil),
            .init(name: "notes", keypath: \DayTask.notes, defaultValue: "", metadata: nil),
            .init(name: "areaID", keypath: \DayTask.areaID, defaultValue: nil, metadata: nil),
            .init(name: "goalID", keypath: \DayTask.goalID, defaultValue: nil, metadata: nil),
            .init(name: "scheduledDate", keypath: \DayTask.scheduledDate, defaultValue: nil, metadata: nil),
            .init(name: "dueDate", keypath: \DayTask.dueDate, defaultValue: nil, metadata: nil),
            .init(name: "isCompleted", keypath: \DayTask.isCompleted, defaultValue: false, metadata: nil),
            .init(name: "completedAt", keypath: \DayTask.completedAt, defaultValue: nil, metadata: nil),
            .init(name: "priorityRaw", keypath: \DayTask.priorityRaw, defaultValue: 0, metadata: nil),
            .init(name: "sortOrder", keypath: \DayTask.sortOrder, defaultValue: 0.0, metadata: nil),
            .init(name: "repeatRuleRaw", keypath: \DayTask.repeatRuleRaw, defaultValue: "", metadata: nil),
            .init(name: "createdAt", keypath: \DayTask.createdAt, defaultValue: Date(timeIntervalSince1970: 0), metadata: nil),
            .init(name: "recurrenceSourceID", keypath: \DayTask.recurrenceSourceID, defaultValue: nil, metadata: nil),
            .init(name: "recurrenceOccurrenceDate", keypath: \DayTask.recurrenceOccurrenceDate, defaultValue: nil, metadata: nil),
            .init(name: "recurrenceSuccessorID", keypath: \DayTask.recurrenceSuccessorID, defaultValue: nil, metadata: nil)
        ]
    }

    public var id: UUID {
        get { _$observationRegistrar.access(self, keyPath: \.id); return getValue(forKey: \.id) }
        set { _$observationRegistrar.withMutation(of: self, keyPath: \.id) { setValue(forKey: \.id, to: newValue) } }
    }
    public var title: String {
        get { _$observationRegistrar.access(self, keyPath: \.title); return getValue(forKey: \.title) }
        set { _$observationRegistrar.withMutation(of: self, keyPath: \.title) { setValue(forKey: \.title, to: newValue) } }
    }
    public var notes: String {
        get { _$observationRegistrar.access(self, keyPath: \.notes); return getValue(forKey: \.notes) }
        set { _$observationRegistrar.withMutation(of: self, keyPath: \.notes) { setValue(forKey: \.notes, to: newValue) } }
    }
    public var areaID: UUID? {
        get { _$observationRegistrar.access(self, keyPath: \.areaID); return getValue(forKey: \.areaID) }
        set { _$observationRegistrar.withMutation(of: self, keyPath: \.areaID) { setValue(forKey: \.areaID, to: newValue) } }
    }
    public var goalID: UUID? {
        get { _$observationRegistrar.access(self, keyPath: \.goalID); return getValue(forKey: \.goalID) }
        set { _$observationRegistrar.withMutation(of: self, keyPath: \.goalID) { setValue(forKey: \.goalID, to: newValue) } }
    }
    public var scheduledDate: Date? {
        get { _$observationRegistrar.access(self, keyPath: \.scheduledDate); return getValue(forKey: \.scheduledDate) }
        set { _$observationRegistrar.withMutation(of: self, keyPath: \.scheduledDate) { setValue(forKey: \.scheduledDate, to: newValue) } }
    }
    public var dueDate: Date? {
        get { _$observationRegistrar.access(self, keyPath: \.dueDate); return getValue(forKey: \.dueDate) }
        set { _$observationRegistrar.withMutation(of: self, keyPath: \.dueDate) { setValue(forKey: \.dueDate, to: newValue) } }
    }
    public var isCompleted: Bool {
        get { _$observationRegistrar.access(self, keyPath: \.isCompleted); return getValue(forKey: \.isCompleted) }
        set { _$observationRegistrar.withMutation(of: self, keyPath: \.isCompleted) { setValue(forKey: \.isCompleted, to: newValue) } }
    }
    public var completedAt: Date? {
        get { _$observationRegistrar.access(self, keyPath: \.completedAt); return getValue(forKey: \.completedAt) }
        set { _$observationRegistrar.withMutation(of: self, keyPath: \.completedAt) { setValue(forKey: \.completedAt, to: newValue) } }
    }
    public var priorityRaw: Int {
        get { _$observationRegistrar.access(self, keyPath: \.priorityRaw); return getValue(forKey: \.priorityRaw) }
        set { _$observationRegistrar.withMutation(of: self, keyPath: \.priorityRaw) { setValue(forKey: \.priorityRaw, to: newValue) } }
    }
    public var sortOrder: Double {
        get { _$observationRegistrar.access(self, keyPath: \.sortOrder); return getValue(forKey: \.sortOrder) }
        set { _$observationRegistrar.withMutation(of: self, keyPath: \.sortOrder) { setValue(forKey: \.sortOrder, to: newValue) } }
    }
    public var repeatRuleRaw: String {
        get { _$observationRegistrar.access(self, keyPath: \.repeatRuleRaw); return getValue(forKey: \.repeatRuleRaw) }
        set { _$observationRegistrar.withMutation(of: self, keyPath: \.repeatRuleRaw) { setValue(forKey: \.repeatRuleRaw, to: newValue) } }
    }
    public var createdAt: Date {
        get { _$observationRegistrar.access(self, keyPath: \.createdAt); return getValue(forKey: \.createdAt) }
        set { _$observationRegistrar.withMutation(of: self, keyPath: \.createdAt) { setValue(forKey: \.createdAt, to: newValue) } }
    }
    /// A stable series identity, not a foreign key: deleting the first task preserves the series.
    public var recurrenceSourceID: UUID? {
        get { _$observationRegistrar.access(self, keyPath: \.recurrenceSourceID); return getValue(forKey: \.recurrenceSourceID) }
        set { _$observationRegistrar.withMutation(of: self, keyPath: \.recurrenceSourceID) { setValue(forKey: \.recurrenceSourceID, to: newValue) } }
    }
    public var recurrenceOccurrenceDate: Date? {
        get { _$observationRegistrar.access(self, keyPath: \.recurrenceOccurrenceDate); return getValue(forKey: \.recurrenceOccurrenceDate) }
        set { _$observationRegistrar.withMutation(of: self, keyPath: \.recurrenceOccurrenceDate) { setValue(forKey: \.recurrenceOccurrenceDate, to: newValue) } }
    }
    /// Retained even when its task is deleted, so undo/redo cannot resurrect that occurrence.
    public var recurrenceSuccessorID: UUID? {
        get { _$observationRegistrar.access(self, keyPath: \.recurrenceSuccessorID); return getValue(forKey: \.recurrenceSuccessorID) }
        set { _$observationRegistrar.withMutation(of: self, keyPath: \.recurrenceSuccessorID) { setValue(forKey: \.recurrenceSuccessorID, to: newValue) } }
    }

    public var priority: TaskPriority {
        get { TaskPriority(rawValue: priorityRaw) ?? .none }
        set { priorityRaw = newValue.rawValue }
    }
    public var repeatRule: RepeatRule {
        get { RepeatRule(rawValue: repeatRuleRaw) ?? .none }
        set { repeatRuleRaw = newValue.rawValue }
    }

    public init(id: UUID = UUID(), title: String, notes: String = "", areaID: UUID? = nil,
         scheduledDate: Date? = nil, dueDate: Date? = nil, goalID: UUID? = nil,
         isCompleted: Bool = false, completedAt: Date? = nil, priority: TaskPriority = .none,
         sortOrder: Double = 0, repeatRule: RepeatRule = .none, createdAt: Date = Date(),
         recurrenceSourceID: UUID? = nil, recurrenceOccurrenceDate: Date? = nil,
         recurrenceSuccessorID: UUID? = nil) {
        self.id = id
        self.title = title
        self.notes = notes
        self.areaID = areaID
        self.goalID = goalID
        self.scheduledDate = scheduledDate
        self.dueDate = dueDate
        self.isCompleted = isCompleted
        self.completedAt = isCompleted ? (completedAt ?? Date()) : nil
        self.priorityRaw = priority.rawValue
        self.sortOrder = sortOrder
        self.repeatRuleRaw = repeatRule.rawValue
        self.createdAt = createdAt
        self.recurrenceSourceID = recurrenceSourceID
        self.recurrenceOccurrenceDate = recurrenceOccurrenceDate
        self.recurrenceSuccessorID = recurrenceSuccessorID
    }
}
