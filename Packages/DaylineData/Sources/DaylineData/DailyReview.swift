import Foundation
import SwiftData
import Observation
import DaylineCore

/// One reflective note for one captured civil calendar day.
/// `dayKey` is the business identity; it never changes when the viewer changes time zone.
public final class DailyReview: PersistentModel {
    private var _$backingData: any BackingData<DailyReview> = DailyReview.createBackingData()
    public var persistentBackingData: any BackingData<DailyReview> {
        get { _$backingData }
        set { _$backingData = newValue }
    }
    private let _$observationRegistrar = ObservationRegistrar()
    public required init(backingData: any BackingData<DailyReview>) { persistentBackingData = backingData }

    public static var schemaMetadata: [Schema.PropertyMetadata] {
        [
            .init(name: "id", keypath: \DailyReview.id, defaultValue: nil, metadata: Schema.Attribute(.unique)),
            .init(name: "dayKey", keypath: \DailyReview.dayKey, defaultValue: "", metadata: Schema.Attribute(.unique)),
            .init(name: "timeZoneID", keypath: \DailyReview.timeZoneID, defaultValue: "UTC", metadata: nil),
            .init(name: "learned", keypath: \DailyReview.learned, defaultValue: "", metadata: nil),
            .init(name: "growth", keypath: \DailyReview.growth, defaultValue: "", metadata: nil),
            .init(name: "nextStep", keypath: \DailyReview.nextStep, defaultValue: "", metadata: nil),
            .init(name: "freeformNotes", keypath: \DailyReview.freeformNotes, defaultValue: "", metadata: nil),
            .init(name: "createdAt", keypath: \DailyReview.createdAt, defaultValue: nil, metadata: nil),
            .init(name: "updatedAt", keypath: \DailyReview.updatedAt, defaultValue: nil, metadata: nil)
        ]
    }

    public var id: UUID {
        get { _$observationRegistrar.access(self, keyPath: \.id); return getValue(forKey: \.id) }
        set { _$observationRegistrar.withMutation(of: self, keyPath: \.id) { setValue(forKey: \.id, to: newValue) } }
    }
    public var dayKey: String {
        get { _$observationRegistrar.access(self, keyPath: \.dayKey); return getValue(forKey: \.dayKey) }
        set { _$observationRegistrar.withMutation(of: self, keyPath: \.dayKey) { setValue(forKey: \.dayKey, to: newValue) } }
    }
    public var timeZoneID: String {
        get { _$observationRegistrar.access(self, keyPath: \.timeZoneID); return getValue(forKey: \.timeZoneID) }
        set { _$observationRegistrar.withMutation(of: self, keyPath: \.timeZoneID) { setValue(forKey: \.timeZoneID, to: newValue) } }
    }
    public var learned: String {
        get { _$observationRegistrar.access(self, keyPath: \.learned); return getValue(forKey: \.learned) }
        set { _$observationRegistrar.withMutation(of: self, keyPath: \.learned) { setValue(forKey: \.learned, to: newValue) } }
    }
    public var growth: String {
        get { _$observationRegistrar.access(self, keyPath: \.growth); return getValue(forKey: \.growth) }
        set { _$observationRegistrar.withMutation(of: self, keyPath: \.growth) { setValue(forKey: \.growth, to: newValue) } }
    }
    public var nextStep: String {
        get { _$observationRegistrar.access(self, keyPath: \.nextStep); return getValue(forKey: \.nextStep) }
        set { _$observationRegistrar.withMutation(of: self, keyPath: \.nextStep) { setValue(forKey: \.nextStep, to: newValue) } }
    }
    public var freeformNotes: String {
        get { _$observationRegistrar.access(self, keyPath: \.freeformNotes); return getValue(forKey: \.freeformNotes) }
        set { _$observationRegistrar.withMutation(of: self, keyPath: \.freeformNotes) { setValue(forKey: \.freeformNotes, to: newValue) } }
    }
    public var createdAt: Date {
        get { _$observationRegistrar.access(self, keyPath: \.createdAt); return getValue(forKey: \.createdAt) }
        set { _$observationRegistrar.withMutation(of: self, keyPath: \.createdAt) { setValue(forKey: \.createdAt, to: newValue) } }
    }
    public var updatedAt: Date {
        get { _$observationRegistrar.access(self, keyPath: \.updatedAt); return getValue(forKey: \.updatedAt) }
        set { _$observationRegistrar.withMutation(of: self, keyPath: \.updatedAt) { setValue(forKey: \.updatedAt, to: newValue) } }
    }

    public init(id: UUID, dayKey: String, timeZoneID: String, learned: String = "", growth: String = "",
                nextStep: String = "", freeformNotes: String = "", createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.dayKey = dayKey
        self.timeZoneID = timeZoneID
        self.learned = learned
        self.growth = growth
        self.nextStep = nextStep
        self.freeformNotes = freeformNotes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public var hasContent: Bool {
        [learned, growth, nextStep, freeformNotes].contains {
            !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
}

public struct DailyReviewRecord: Codable {
    public var id: UUID
    public var dayKey: String
    public var timeZoneID: String
    public var learned: String
    public var growth: String
    public var nextStep: String
    public var freeformNotes: String
    public var createdAt: Date
    public var updatedAt: Date

    public init(_ review: DailyReview) {
        id = review.id; dayKey = review.dayKey; timeZoneID = review.timeZoneID
        learned = review.learned; growth = review.growth; nextStep = review.nextStep
        freeformNotes = review.freeformNotes; createdAt = review.createdAt; updatedAt = review.updatedAt
    }

    public init(id: UUID, dayKey: String, timeZoneID: String, learned: String = "", growth: String = "",
                nextStep: String = "", freeformNotes: String = "", createdAt: Date, updatedAt: Date) {
        self.id = id; self.dayKey = dayKey; self.timeZoneID = timeZoneID
        self.learned = learned; self.growth = growth; self.nextStep = nextStep
        self.freeformNotes = freeformNotes; self.createdAt = createdAt; self.updatedAt = updatedAt
    }

    public func model() -> DailyReview {
        DailyReview(id: id, dayKey: dayKey, timeZoneID: timeZoneID, learned: learned, growth: growth,
                    nextStep: nextStep, freeformNotes: freeformNotes, createdAt: createdAt, updatedAt: updatedAt)
    }

    public func apply(to review: DailyReview) {
        review.timeZoneID = timeZoneID
        review.learned = learned; review.growth = growth; review.nextStep = nextStep
        review.freeformNotes = freeformNotes; review.createdAt = createdAt; review.updatedAt = updatedAt
    }
}

public enum DailyReviewDay {
    public static func key(for date: Date, timeZone: TimeZone = .current) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return DaylineDateSelection.dayKey(date, calendar: calendar)
    }

    public static func isValid(_ key: String) -> Bool { components(for: key) != nil }

    public static func date(for key: String, timeZone: TimeZone = .current) -> Date? {
        guard var parts = components(for: key) else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        parts.calendar = calendar
        parts.timeZone = timeZone
        parts.hour = 12
        guard let date = calendar.date(from: parts), self.key(for: date, timeZone: timeZone) == key else { return nil }
        return date
    }

    public static func addingDays(_ value: Int, to key: String) -> String? {
        let utc = TimeZone(secondsFromGMT: 0)!
        guard let date = date(for: key, timeZone: utc) else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = utc
        guard let shifted = calendar.date(byAdding: .day, value: value, to: date) else { return nil }
        return self.key(for: shifted, timeZone: utc)
    }

    public static func stableID(for key: String) -> UUID {
        DaylineIdentity.stableUUID("dayline.daily-review|\(key)")
    }

    private static func components(for key: String) -> DateComponents? {
        let values = key.split(separator: "-", omittingEmptySubsequences: false)
        guard key.count == 10, values.count == 3,
              values[0].count == 4, values[1].count == 2, values[2].count == 2,
              let year = Int(values[0]), let month = Int(values[1]), let day = Int(values[2]),
              (1...9999).contains(year), (1...12).contains(month), (1...31).contains(day) else { return nil }
        let utc = TimeZone(secondsFromGMT: 0)!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = utc
        let parts = DateComponents(calendar: calendar, timeZone: utc, year: year, month: month, day: day, hour: 12)
        guard let date = calendar.date(from: parts), self.key(for: date, timeZone: utc) == key else { return nil }
        return DateComponents(year: year, month: month, day: day)
    }
}
