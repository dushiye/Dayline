import Foundation
import CryptoKit

/// Business identity for records that may exist as separate SwiftData objects.
/// A shared UUID is not a CloudKit record name and is not a PersistentIdentifier.
public enum DaylineIdentity {
    public static func stableUUID(_ key: String) -> UUID {
        var bytes = Array(SHA256.hash(data: Data(key.utf8)).prefix(16))
        bytes[6] = (bytes[6] & 0x0F) | 0x50
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        return UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
                           bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]))
    }

    /// Same key the Mac store uses for the next repeating occurrence.
    public static func recurrenceSuccessorID(source: UUID, occurrence: Date, calendar: Calendar) -> UUID {
        let components = calendar.dateComponents([.era, .year, .month, .day], from: occurrence)
        let key = "\(source.uuidString)|\(calendar.identifier)|\(components.era ?? 1)-\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
        return stableUUID(key)
    }

    /// Logical history identity. `generation` counts prior events for that task on the device
    /// that created it. Two devices that have seen the same prefix assign the same id.
    /// A device that missed an intermediate reopen assigns a different generation, which is a
    /// conflict rather than an automatic merge.
    public static func planningEventID(taskID: UUID, kind: String, dayKey: String, generation: Int) -> UUID {
        stableUUID("\(taskID.uuidString)|\(kind)|\(dayKey)|\(generation)")
    }

    public static func duplicateBusinessIDs<T>(_ items: [T], id: (T) -> UUID) -> [UUID] {
        var seen = Set<UUID>()
        var duplicates = Set<UUID>()
        for item in items {
            let value = id(item)
            if !seen.insert(value).inserted { duplicates.insert(value) }
        }
        return duplicates.sorted { $0.uuidString < $1.uuidString }
    }
}

public struct TrackedRecord: Equatable {
    public var businessID: UUID
    public var persistentID: String
    public var updatedAt: Date

    public init(businessID: UUID, persistentID: String, updatedAt: Date) {
        self.businessID = businessID
        self.persistentID = persistentID
        self.updatedAt = updatedAt
    }
}

public enum RecordMerge: Equatable {
    /// Same business id and same persistent id: one SwiftData object.
    case sameObject
    /// Same business id, different persistent ids: two rows CloudKit would not automatically merge.
    case duplicateBusinessID(keep: TrackedRecord, discard: [TrackedRecord])
    /// Different business ids.
    case distinct
}

public enum DaylineMerge {
    public static func classify(_ lhs: TrackedRecord, _ rhs: TrackedRecord) -> RecordMerge {
        guard lhs.businessID == rhs.businessID else { return .distinct }
        guard lhs.persistentID != rhs.persistentID else { return .sameObject }
        let ordered = [lhs, rhs].sorted { a, b in
            if a.updatedAt != b.updatedAt { return a.updatedAt > b.updatedAt }
            return a.persistentID < b.persistentID
        }
        return .duplicateBusinessID(keep: ordered[0], discard: Array(ordered.dropFirst()))
    }

    public enum EventImport: Equatable {
        case insert
        case alreadyStored
        case conflictingGeneration(existing: UUID, incoming: UUID)
    }

    public static func importEvent(existingIDs: Set<UUID>, existingSameTransition: UUID?, incoming: UUID) -> EventImport {
        if existingIDs.contains(incoming) { return .alreadyStored }
        if let existingSameTransition, existingSameTransition != incoming {
            return .conflictingGeneration(existing: existingSameTransition, incoming: incoming)
        }
        return .insert
    }
}
