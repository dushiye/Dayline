import Foundation

enum DaylineExportFormat: String, CaseIterable, Identifiable, Sendable {
    case pdf, markdown = "md", png
    var id: String { rawValue }
    var label: String { self == .markdown ? "Markdown" : rawValue.uppercased() }
}

struct ExportTaskSnapshot: Sendable {
    var id: UUID = UUID()
    var title: String
    var notes: String = ""
    var scheduledDate: Date? = nil
    var dueDate: Date? = nil
    var isCompleted: Bool = false
    var priority: Int = 0
    var area: String? = nil
    var goal: String? = nil
    var sortOrder: Double = 0
}

struct ExportIdeaSnapshot: Sendable {
    var id: UUID = UUID()
    var title: String
    var body: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var isPinned: Bool = false
    var isArchived: Bool = false
    var area: String? = nil
    var goal: String? = nil
}

struct ExportBlock: Sendable {
    enum Style: Sendable { case title, heading, subheading, task, body, metadata }
    var text: String
    var style: Style
}

struct ExportDocument: Sendable {
    var filename: String
    var blocks: [ExportBlock]

    var markdown: String {
        blocks.map { block in
            switch block.style {
            case .title: return "# " + Self.escapeHeading(block.text)
            case .heading: return "## " + Self.escapeHeading(block.text)
            case .subheading: return "### " + Self.escapeHeading(block.text)
            case .task: return "- " + block.text
            case .body, .metadata: return block.text
            }
        }.joined(separator: "\n\n") + "\n"
    }
    private static func escapeHeading(_ value: String) -> String {
        value.replacingOccurrences(of: "\n", with: "  \n").replacingOccurrences(of: "#", with: "\\#")
    }
}

enum DaylineExportError: LocalizedError {
    case invalidRange, emptySelection, tooLarge(String), render(String), write(String)
    var errorDescription: String? {
        switch self {
        case .invalidRange: return "日期范围无效，或超过 366 天；请选择较小的批次。"
        case .emptySelection: return "请选择至少一条灵感。"
        case .tooLarge(let message), .render(let message), .write(let message): return message
        }
    }
}

enum DaylineExporter {
    static let attribution = "日期归属：优先使用计划日期，没有计划日期时使用截止日期；每项任务只归属一天。与“今天”视图的截止提醒范围不同。"

    static func dates(from start: Date, through end: Date, calendar: Calendar = .current) throws -> [Date] {
        let first = calendar.startOfDay(for: start), last = calendar.startOfDay(for: end)
        guard last >= first, let days = calendar.dateComponents([.day], from: first, to: last).day,
              days < 366 else { throw DaylineExportError.invalidRange }
        return (0...days).compactMap { calendar.date(byAdding: .day, value: $0, to: first) }
    }

    static func dayLabel(_ date: Date, calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar; formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    static func weekday(_ date: Date, calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar; formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "zh_CN"); formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }

    static func documents(planTasks: [ExportTaskSnapshot], dates: [Date], combined: Bool,
                          calendar: Calendar = .current) throws -> [ExportDocument] {
        let days = Set(dates.map { calendar.startOfDay(for: $0) }).sorted()
        guard !days.isEmpty, days.count <= 366 else { throw DaylineExportError.invalidRange }
        var seen = Set<UUID>()
        let tasks = planTasks.filter { seen.insert($0.id).inserted }.sorted {
            if $0.sortOrder != $1.sortOrder { return $0.sortOrder < $1.sortOrder }
            if $0.title != $1.title { return $0.title < $1.title }
            return $0.id.uuidString < $1.id.uuidString
        }
        let groups = days.map { day -> ExportDocument in
            var blocks = [ExportBlock(text: dayLabel(day, calendar: calendar) + " · " + weekday(day, calendar: calendar), style: .heading)]
            let matching = tasks.filter { task in
                (task.scheduledDate ?? task.dueDate).map { calendar.isDate($0, inSameDayAs: day) } ?? false
            }
            blocks.append(.init(text: "已完成 \(matching.filter(\.isCompleted).count) / \(matching.count) 项", style: .metadata))
            if matching.isEmpty { blocks.append(.init(text: "当天无计划", style: .body)) }
            let standardAreas = ["Learning", "Research", "Health"]
            let extraAreas = Set(matching.compactMap(\.area)).subtracting(standardAreas).sorted()
            let areas = standardAreas + extraAreas + (matching.contains { $0.area == nil } ? ["未分类"] : [])
            for area in areas {
                blocks.append(.init(text: area, style: .subheading))
                let areaTasks = matching.filter { ($0.area ?? "未分类") == area }
                if areaTasks.isEmpty { blocks.append(.init(text: "无任务", style: .body)) }
                for task in areaTasks {
                blocks.append(.init(text: "\(task.isCompleted ? "[x]" : "[ ]") \(task.title)", style: .task))
                var metadata = ["状态：\(task.isCompleted ? "已完成" : "未完成")", "优先级：\(["无", "低", "中", "高"][min(3, max(0, task.priority))])"]
                if let date = task.scheduledDate { metadata.append("计划：" + dayLabel(date, calendar: calendar)) }
                if let date = task.dueDate { metadata.append("截止：" + dayLabel(date, calendar: calendar)) }
                if let area = task.area { metadata.append("领域：" + area) }
                if let goal = task.goal { metadata.append("目标：" + goal) }
                blocks.append(.init(text: metadata.joined(separator: " · "), style: .metadata))
                if !task.notes.isEmpty { blocks.append(.init(text: task.notes, style: .body)) }
                }
            }
            return ExportDocument(filename: "Dayline-Plan-" + dayLabel(day, calendar: calendar), blocks: blocks)
        }
        if combined {
            let range = dayLabel(days[0], calendar: calendar) + (days.count > 1 ? " 至 " + dayLabel(days.last!, calendar: calendar) : "")
            let included = tasks.filter { task in (task.scheduledDate ?? task.dueDate).map { days.contains(calendar.startOfDay(for: $0)) } ?? false }
            let stats = "已完成 \(included.filter(\.isCompleted).count) / \(included.count) 项"
            let filename = "Dayline-Plan-" + dayLabel(days[0], calendar: calendar) + (days.count > 1 ? "_to_" + dayLabel(days.last!, calendar: calendar) : "")
            return [.init(filename: filename, blocks: [.init(text: "Dayline · 计划", style: .title), .init(text: range + "\n" + stats + "\n" + attribution, style: .metadata)] + groups.flatMap(\.blocks))]
        }
        return groups.map { .init(filename: $0.filename, blocks: [.init(text: "Dayline · 计划", style: .title), .init(text: attribution, style: .metadata)] + $0.blocks) }
    }

    static func documents(ideas: [ExportIdeaSnapshot], combined: Bool) throws -> [ExportDocument] {
        guard !ideas.isEmpty else { throw DaylineExportError.emptySelection }
        var seen = Set<UUID>()
        let documents = ideas.filter { seen.insert($0.id).inserted }.sorted {
            if $0.isPinned != $1.isPinned { return $0.isPinned }
            if $0.updatedAt != $1.updatedAt { return $0.updatedAt > $1.updatedAt }
            return $0.id.uuidString < $1.id.uuidString
        }.map { idea -> ExportDocument in
            let title = idea.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "未命名灵感" : idea.title
            var metadata = ["创建：" + dayLabel(idea.createdAt), "更新：" + dayLabel(idea.updatedAt), idea.isArchived ? "已归档" : "未归档"]
            if idea.isPinned { metadata.append("已置顶") }
            if let area = idea.area { metadata.append("领域：" + area) }
            if let goal = idea.goal { metadata.append("目标：" + goal) }
            return .init(filename: "Dayline-Idea-" + title, blocks: [.init(text: title, style: .heading), .init(text: metadata.joined(separator: " · "), style: .metadata), .init(text: idea.body.isEmpty ? "（空白正文）" : idea.body, style: .body)])
        }
        let header = ExportBlock(text: "Dayline · 灵感", style: .title)
        if combined { return [.init(filename: "Dayline-Ideas", blocks: [header] + documents.flatMap(\.blocks))] }
        return documents.map { .init(filename: $0.filename, blocks: [header] + $0.blocks) }
    }
}
