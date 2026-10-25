import Foundation
import SwiftData
import Observation

// Additive v1.1 entities. Existing entity schemas remain byte-for-byte unchanged.
final class Idea: PersistentModel {
    private var _$backingData: any BackingData<Idea> = Idea.createBackingData()
    var persistentBackingData: any BackingData<Idea> {
        get { _$backingData }
        set { _$backingData = newValue }
    }
    private let _$observationRegistrar = ObservationRegistrar()
    required init(backingData: any BackingData<Idea>) { persistentBackingData = backingData }
    static var schemaMetadata: [Schema.PropertyMetadata] {
        [
            .init(name: "id", keypath: \Idea.id, defaultValue: nil, metadata: Schema.Attribute(.unique)),
            .init(name: "title", keypath: \Idea.title, defaultValue: "", metadata: nil),
            .init(name: "body", keypath: \Idea.body, defaultValue: "", metadata: nil),
            .init(name: "createdAt", keypath: \Idea.createdAt, defaultValue: nil, metadata: nil),
            .init(name: "updatedAt", keypath: \Idea.updatedAt, defaultValue: nil, metadata: nil),
            .init(name: "isPinned", keypath: \Idea.isPinned, defaultValue: false, metadata: nil),
            .init(name: "isArchived", keypath: \Idea.isArchived, defaultValue: false, metadata: nil),
            .init(name: "areaID", keypath: \Idea.areaID, defaultValue: nil, metadata: nil),
            .init(name: "goalID", keypath: \Idea.goalID, defaultValue: nil, metadata: nil)
        ]
    }
    var id: UUID {
        get { _$observationRegistrar.access(self, keyPath: \.id); return getValue(forKey: \.id) }
        set { _$observationRegistrar.withMutation(of: self, keyPath: \.id) { setValue(forKey: \.id, to: newValue) } }
    }
    var title: String {
        get { _$observationRegistrar.access(self, keyPath: \.title); return getValue(forKey: \.title) }
        set { _$observationRegistrar.withMutation(of: self, keyPath: \.title) { setValue(forKey: \.title, to: newValue) } }
    }
    var body: String {
        get { _$observationRegistrar.access(self, keyPath: \.body); return getValue(forKey: \.body) }
        set { _$observationRegistrar.withMutation(of: self, keyPath: \.body) { setValue(forKey: \.body, to: newValue) } }
    }
    var createdAt: Date {
        get { _$observationRegistrar.access(self, keyPath: \.createdAt); return getValue(forKey: \.createdAt) }
        set { _$observationRegistrar.withMutation(of: self, keyPath: \.createdAt) { setValue(forKey: \.createdAt, to: newValue) } }
    }
    var updatedAt: Date {
        get { _$observationRegistrar.access(self, keyPath: \.updatedAt); return getValue(forKey: \.updatedAt) }
        set { _$observationRegistrar.withMutation(of: self, keyPath: \.updatedAt) { setValue(forKey: \.updatedAt, to: newValue) } }
    }
    var isPinned: Bool {
        get { _$observationRegistrar.access(self, keyPath: \.isPinned); return getValue(forKey: \.isPinned) }
        set { _$observationRegistrar.withMutation(of: self, keyPath: \.isPinned) { setValue(forKey: \.isPinned, to: newValue) } }
    }
    var isArchived: Bool {
        get { _$observationRegistrar.access(self, keyPath: \.isArchived); return getValue(forKey: \.isArchived) }
        set { _$observationRegistrar.withMutation(of: self, keyPath: \.isArchived) { setValue(forKey: \.isArchived, to: newValue) } }
    }
    var areaID: UUID? {
        get { _$observationRegistrar.access(self, keyPath: \.areaID); return getValue(forKey: \.areaID) }
        set { _$observationRegistrar.withMutation(of: self, keyPath: \.areaID) { setValue(forKey: \.areaID, to: newValue) } }
    }
    var goalID: UUID? {
        get { _$observationRegistrar.access(self, keyPath: \.goalID); return getValue(forKey: \.goalID) }
        set { _$observationRegistrar.withMutation(of: self, keyPath: \.goalID) { setValue(forKey: \.goalID, to: newValue) } }
    }
    init(id: UUID = UUID(), title: String = "", body: String = "", createdAt: Date = Date(), updatedAt: Date = Date(), isPinned: Bool = false, isArchived: Bool = false, areaID: UUID? = nil, goalID: UUID? = nil) {
        self.id = id; self.title = title; self.body = body
        self.createdAt = createdAt; self.updatedAt = updatedAt
        self.isPinned = isPinned; self.isArchived = isArchived; self.areaID = areaID; self.goalID = goalID
    }
}

final class PlanningEventEntity: PersistentModel {
    private var _$backingData: any BackingData<PlanningEventEntity> = PlanningEventEntity.createBackingData()
    var persistentBackingData: any BackingData<PlanningEventEntity> {
        get { _$backingData }
        set { _$backingData = newValue }
    }
    private let _$observationRegistrar = ObservationRegistrar()
    required init(backingData: any BackingData<PlanningEventEntity>) { persistentBackingData = backingData }
    static var schemaMetadata: [Schema.PropertyMetadata] {
        [
            .init(name: "id", keypath: \PlanningEventEntity.id, defaultValue: nil, metadata: Schema.Attribute(.unique)),
            .init(name: "payload", keypath: \PlanningEventEntity.payload, defaultValue: nil, metadata: nil),
            .init(name: "sequence", keypath: \PlanningEventEntity.sequence, defaultValue: 0, metadata: nil)
        ]
    }
    var id: UUID {
        get { _$observationRegistrar.access(self, keyPath: \.id); return getValue(forKey: \.id) }
        set { _$observationRegistrar.withMutation(of: self, keyPath: \.id) { setValue(forKey: \.id, to: newValue) } }
    }
    var payload: Data {
        get { _$observationRegistrar.access(self, keyPath: \.payload); return getValue(forKey: \.payload) }
        set { _$observationRegistrar.withMutation(of: self, keyPath: \.payload) { setValue(forKey: \.payload, to: newValue) } }
    }
    var sequence: Int {
        get { _$observationRegistrar.access(self, keyPath: \.sequence); return getValue(forKey: \.sequence) }
        set { _$observationRegistrar.withMutation(of: self, keyPath: \.sequence) { setValue(forKey: \.sequence, to: newValue) } }
    }
    init(_ record: PlanningEventRecord, sequence: Int = 0) throws {
        self.id = record.id
        self.sequence = sequence
        self.payload = try DaylineBackup.encoder().encode(record)
    }
    func record() throws -> PlanningEventRecord {
        try DaylineBackup.decoder().decode(PlanningEventRecord.self, from: payload)
    }
}


