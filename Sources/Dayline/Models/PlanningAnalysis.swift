import Foundation

enum PlanningEventKind: String, Codable {
    case baseline, planned, completed, reopened, rescheduled, deleted
}

/// Immutable observations. Never backdate a baseline when importing existing tasks.
struct PlanningEventRecord: Codable, Identifiable {
    var id: UUID
    var taskID: UUID
    var kind: PlanningEventKind
    var occurredAt: Date
    var dayKey: String?
    var newDayKey: String?
    var timeZoneID: String
    var taskTitle: String
    var areaID: UUID?
    var recurrenceSourceID: UUID?
    var occurrenceDate: Date?
    var wasCompleted: Bool

    init(id: UUID = UUID(), taskID: UUID, kind: PlanningEventKind, occurredAt: Date,
         dayKey: String?, newDayKey: String? = nil, timeZoneID: String,
         taskTitle: String, areaID: UUID? = nil, recurrenceSourceID: UUID? = nil,
         occurrenceDate: Date? = nil, wasCompleted: Bool = false) {
        self.id = id; self.taskID = taskID; self.kind = kind; self.occurredAt = occurredAt
        self.dayKey = dayKey; self.newDayKey = newDayKey; self.timeZoneID = timeZoneID
        self.taskTitle = taskTitle; self.areaID = areaID
        self.recurrenceSourceID = recurrenceSourceID; self.occurrenceDate = occurrenceDate
        self.wasCompleted = wasCompleted
    }
}

struct PlanningDaySummary: Identifiable {
    var id: String { dayKey }
    let dayKey: String
    /// Unique tasks ever assigned to this day during observed history, including additions.
    var planned = 0
    /// Tasks whose current, non-undone completion was observed on this local date.
    /// Includes unscheduled tasks; can exceed planned. Baseline completion is never inferred.
    var actualCompleted = 0
    /// Morning-plan tasks completed no later than their plan date.
    var originalCompleted = 0
    var originalPlanned = 0
    /// First assigned on or after the plan date. Each task counts once per plan date.
    var addedToday = 0
    /// Tasks currently moved away from this day. Returning clears this count.
    var activelyRescheduled = 0
    /// Tasks deleted while assigned to this day. Restoring clears this count.
    var deleted = 0
    var isEffectivePlanDay = false
    var hasPartialBaseline = false
}

struct PlanningWindowSummary {
    let days: [PlanningDaySummary]
    var dayCount: Int { days.count }
    var planned: Int { days.reduce(0) { $0 + $1.planned } }
    var actualCompleted: Int { days.reduce(0) { $0 + $1.actualCompleted } }
    var originalCompleted: Int { days.reduce(0) { $0 + $1.originalCompleted } }
    var originalPlanned: Int { days.reduce(0) { $0 + $1.originalPlanned } }
    var addedToday: Int { days.reduce(0) { $0 + $1.addedToday } }
    var activelyRescheduled: Int { days.reduce(0) { $0 + $1.activelyRescheduled } }
    var deleted: Int { days.reduce(0) { $0 + $1.deleted } }
    /// Comparable morning-plan adherence, not actualCompleted / planned.
    var completionRate: Double? {
        originalPlanned > 0 ? Double(originalCompleted) / Double(originalPlanned) : nil
    }
}

struct PlanningCoachAdvice {
    let hasEnoughHistory: Bool
    let title: String
    let message: String
    let basisDayCount: Int
}

struct PlanningReport {
    let days: [PlanningDaySummary]
    let recent7: PlanningWindowSummary
    let recent14: PlanningWindowSummary
    let recent30: PlanningWindowSummary
    let coach: PlanningCoachAdvice
}

/// Pure analysis: no task mutation, storage, network, or dependence on today's task snapshot.
/// Persisted day keys retain the capture zone's calendar date even after travel. Event-local
/// completion/addition dates use the captured timeZoneID (UTC fallback for invalid identifiers).
/// `timeZone` only determines the current reporting date; today/future never train the coach.
/// Identity is taskID: recurring occurrences must have their own task IDs; recurrenceSourceID
/// is lineage, never a dedup key. Duplicate event IDs are ignored; same-time events retain
/// input order, so callers must preserve append order. Undo uses inverse observations.
enum PlanningAnalysis {
    private struct Entry {
        var original: Bool
        var partialBaseline: Bool
        var observedByPlanDay: Bool
        var departure: PlanningEventKind?
    }
    private struct State {
        var activeDay: String?
        var completion: PlanningEventRecord?
    }

    static func dayKey(for date: Date, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    static func analyze(events: [PlanningEventRecord], asOf: Date = Date(),
                        timeZone: TimeZone = .current) -> PlanningReport {
        var seen = Set<UUID>()
        let ordered = events.enumerated().filter { $0.element.occurredAt <= asOf }
            .sorted { a, b in
                a.element.occurredAt == b.element.occurredAt ? a.offset < b.offset : a.element.occurredAt < b.element.occurredAt
            }.map(\.element).filter { seen.insert($0.id).inserted }
        var entries: [String: [UUID: Entry]] = [:]
        var states: [UUID: State] = [:]

        func depart(_ event: PlanningEventRecord, from key: String?, reason: PlanningEventKind) {
            guard let key else { return }
            let zone = TimeZone(identifier: event.timeZoneID) ?? TimeZone(secondsFromGMT: 0)!
            if dayKey(for: event.occurredAt, timeZone: zone) < key {
                // A task removed before that day began was never part of its morning plan.
                entries[key]?.removeValue(forKey: event.taskID)
            } else {
                entries[key]?[event.taskID]?.departure = reason
            }
        }

        func assign(_ event: PlanningEventRecord, to key: String?, baseline: Bool) {
            guard let key, validKey(key) else { return }
            let zone = TimeZone(identifier: event.timeZoneID) ?? TimeZone(secondsFromGMT: 0)!
            let observedDay = dayKey(for: event.occurredAt, timeZone: zone)
            // A newly observed overdue baseline proves nothing about its historical plan.
            guard !baseline || observedDay <= key else { return }
            if var existing = entries[key]?[event.taskID] {
                existing.departure = nil
                entries[key]?[event.taskID] = existing
            } else {
                // Moving/restoring a task already finished creates no new work commitment.
                guard !event.wasCompleted else { return }
                entries[key, default: [:]][event.taskID] = Entry(
                    original: observedDay < key,
                    partialBaseline: baseline && observedDay == key,
                    observedByPlanDay: observedDay <= key,
                    departure: nil)
            }
        }

        for event in ordered {
            var state = states[event.taskID] ?? State()
            switch event.kind {
            case .baseline, .planned:
                if let old = state.activeDay, old != event.dayKey {
                    depart(event, from: old, reason: .rescheduled)
                }
                state.activeDay = event.dayKey
                if event.kind != .baseline || !event.wasCompleted {
                    assign(event, to: event.dayKey, baseline: event.kind == .baseline)
                }
                // A restored completed task does not prove when completion occurred.
                if !event.wasCompleted { state.completion = nil }
            case .rescheduled:
                if let old = event.dayKey, old != event.newDayKey {
                    depart(event, from: old, reason: .rescheduled)
                }
                state.activeDay = event.newDayKey
                assign(event, to: event.newDayKey, baseline: false)
            case .completed:
                // Repeated snapshot observations must not move a completion to a later day.
                if state.completion == nil { state.completion = event }
            case .reopened:
                state.completion = nil
                // Completed baselines (and moves while completed) intentionally create no
                // assignment. Reopening makes that work observable from this moment only.
                // Existing assignments retain their morning/late-add identity and counts.
                state.activeDay = event.dayKey
                if let key = event.dayKey, entries[key]?[event.taskID] == nil {
                    assign(event, to: key, baseline: false)
                }
            case .deleted:
                if let old = event.dayKey ?? state.activeDay {
                    depart(event, from: old, reason: .deleted)
                }
                state.activeDay = nil
                // Deleting a finished task does not erase the work actually completed.
            }
            states[event.taskID] = state
        }

        var days: [String: PlanningDaySummary] = [:]
        let today = dayKey(for: asOf, timeZone: timeZone)
        for (key, tasks) in entries {
            guard !tasks.isEmpty else { continue }
            var day = PlanningDaySummary(dayKey: key)
            day.planned = tasks.count
            for (taskID, entry) in tasks {
                if entry.original { day.originalPlanned += 1 }
                else { day.addedToday += 1 }
                if entry.partialBaseline { day.hasPartialBaseline = true }
                if entry.departure == .rescheduled { day.activelyRescheduled += 1 }
                if entry.departure == .deleted { day.deleted += 1 }
                if entry.original, let completed = states[taskID]?.completion, completed.dayKey == key {
                    let zone = TimeZone(identifier: completed.timeZoneID) ?? TimeZone(secondsFromGMT: 0)!
                    if dayKey(for: completed.occurredAt, timeZone: zone) <= key {
                        day.originalCompleted += 1
                    }
                }
            }
            day.isEffectivePlanDay = key < today && tasks.values.contains { $0.observedByPlanDay } && !day.hasPartialBaseline
            days[key] = day
        }
        for state in states.values {
            guard let event = state.completion else { continue }
            let zone = TimeZone(identifier: event.timeZoneID) ?? TimeZone(secondsFromGMT: 0)!
            let key = dayKey(for: event.occurredAt, timeZone: zone)
            var day = days[key] ?? PlanningDaySummary(dayKey: key)
            day.actualCompleted += 1
            days[key] = day
        }
        let sorted = days.values.sorted { $0.dayKey < $1.dayKey }
        let valid = sorted.filter(\.isEffectivePlanDay)
        let seven = PlanningWindowSummary(days: Array(valid.suffix(7)))
        let fourteen = PlanningWindowSummary(days: Array(valid.suffix(14)))
        let thirty = PlanningWindowSummary(days: Array(valid.suffix(30)))
        let todayWorkload = (entries[today] ?? [:]).filter { taskID, entry in
            guard entry.departure == nil else { return false }
            guard let completed = states[taskID]?.completion else { return true }
            let zone = TimeZone(identifier: completed.timeZoneID) ?? TimeZone(secondsFromGMT: 0)!
            return dayKey(for: completed.occurredAt, timeZone: zone) >= today
        }.count
        return PlanningReport(days: sorted, recent7: seven, recent14: fourteen,
                              recent30: thirty, coach: advice(for: fourteen, todayWorkload: todayWorkload))
    }

    private static func validKey(_ key: String) -> Bool {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false
        guard let date = formatter.date(from: key) else { return false }
        return formatter.string(from: date) == key
    }

    private static func advice(for window: PlanningWindowSummary, todayWorkload: Int) -> PlanningCoachAdvice {
        let count = window.dayCount
        guard count >= 7 else {
            return PlanningCoachAdvice(hasEnoughHistory: false, title: "继续积累计划记录",
                message: "目前有 \(count) 个已结束的有效计划日，至少需要 7 个。迁移前历史和不完整的基线日不用于建议。", basisDayCount: count)
        }
        let prefix = "依据最近 \(count) 个有效计划日（最多 14 个）："
        let rate = window.completionRate
        let rescheduledShare = Double(window.activelyRescheduled) / Double(max(1, window.planned))
        let addedShare = Double(window.addedToday) / Double(max(1, window.planned))
        let poorDays = window.days.filter { $0.originalPlanned > 0 && Double($0.originalCompleted) / Double($0.originalPlanned) < 0.6 }.count
        let title: String
        let detail: String
        let throughput = window.days.map(\.actualCompleted).sorted()
        // Trim one extreme at each end for 10+ days; ordinary seven-day samples use all days.
        let trimmed = count >= 10 ? Array(throughput.dropFirst().dropLast()) : throughput
        let average = Double(trimmed.reduce(0, +)) / Double(max(1, trimmed.count))
        let lower = throughput[(count - 1) / 4]
        let upper = throughput[(count - 1) * 3 / 4]
        let overloadThreshold = max(3, max(Int(ceil(average * 1.5)), upper + 1))
        let positiveDays = throughput.filter { $0 > 0 }.count
        if positiveDays >= 4 && todayWorkload > overloadThreshold {
            title = "今日计划可能偏满"
            detail = "今天仍在计划内的任务共 \(todayWorkload) 项（含今日已完成）；近期每日实际完成通常为 \(lower)–\(upper) 项。可先选定重点，将其余任务留作候选。当天新增和主动改期单独统计，任务大小差异也会影响容量判断。"
        } else if rescheduledShare >= 0.25 {
            title = "为主动调整留出空间"
            detail = "\(window.activelyRescheduled) 项计划已主动改期。可在排计划时预留机动时间；改期单独呈现，不等同于没有行动。"
        } else if addedShare >= 0.3 {
            title = "为当天新增预留容量"
            detail = "\(window.addedToday) 项在计划日当天或之后加入。可减少预先排满的任务，为临时事项留出位置。"
        } else if let rate, rate < 0.6, poorDays >= 4 {
            title = "试着缩小每日承诺"
            detail = "多个计划日的原计划完成比例偏低。可以先减少每日重点，或把较大的任务拆成一次能推进的小步。"
        } else {
            title = "保持可持续的节奏"
            detail = "继续观察原计划完成、当天新增和主动改期的区别；不因单日波动调整整体判断。"
        }
        return PlanningCoachAdvice(hasEnoughHistory: true, title: title,
            message: prefix + detail + " 建议仅供参考，不会自动更改任务。", basisDayCount: count)
    }
}
