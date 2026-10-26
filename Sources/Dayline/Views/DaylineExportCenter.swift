import SwiftUI
import AppKit
import DaylineData

struct DaylineExportCenter: View {
    @AppStorage("exportDirectory") private var lastExportDirectory = ""
    @Environment(DaylineStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var content: ContentKind
    @State private var range: PlanRange = .today
    @State private var start = Date()
    @State private var end = Date()
    @State private var format: DaylineExportFormat = .pdf
    @State private var combined = true
    @State private var ideaScope: IdeaScope
    @State private var selected: Set<UUID>
    @State private var query = ""
    @State private var includeArchived = false
    @State private var areaID: UUID?
    @State private var busy = false
    @State private var choosingFolder = false
    @State private var exportTask: Task<[URL], Error>?
    @State private var message: String?
    @State private var failed = false
    @State private var saved: [URL] = []

    private enum ContentKind: String, CaseIterable { case plans = "每日计划", ideas = "灵感" }
    private enum PlanRange: String, CaseIterable { case today = "今天", day = "指定日期", seven = "连续七天", custom = "自定义范围" }
    private enum IdeaScope: String, CaseIterable { case selected = "所选", all = "全部", filtered = "筛选结果" }

    init(initialIdeaIDs: Set<UUID>? = nil) {
        _content = State(initialValue: initialIdeaIDs == nil ? .plans : .ideas)
        _ideaScope = State(initialValue: initialIdeaIDs == nil ? .all : .selected)
        _selected = State(initialValue: initialIdeaIDs ?? [])
    }

    private var filteredIdeas: [Idea] {
        store.ideas.filter { idea in
            (includeArchived || !idea.isArchived) && (areaID == nil || idea.areaID == areaID)
                && (query.isEmpty || idea.title.localizedCaseInsensitiveContains(query) || idea.body.localizedCaseInsensitiveContains(query))
        }
    }
    private var chosenIdeas: [Idea] {
        switch ideaScope {
        case .all: return store.ideas
        case .filtered: return filteredIdeas
        case .selected: return store.ideas.filter { selected.contains($0.id) }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("导出中心").font(.title2.bold())
                Spacer()
                Button("关闭") { dismiss() }.keyboardShortcut(.cancelAction).disabled(busy || choosingFolder)
            }
            Picker("内容", selection: $content) {
                ForEach(ContentKind.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }.pickerStyle(.segmented)
            Group {
                if content == .plans { planControls } else { ideaControls }
                HStack {
                    Picker("格式", selection: $format) {
                        ForEach(DaylineExportFormat.allCases) { Text($0.label).tag($0) }
                    }
                    Picker("文件组织", selection: $combined) {
                        Text("合并为一个文件").tag(true)
                        Text(content == .plans ? "每天一个文件" : "每条灵感一个文件").tag(false)
                    }
                }
            }.disabled(busy || choosingFolder)
            Text(format == .pdf ? "A4 自动分页，中文文本可选择和搜索。" : format == .png ? "以 2 倍分辨率生成完整长图；过长内容会明确提示改用 PDF 或分开导出。" : "UTF-8 Markdown，保留正文段落。")
                .font(.caption).foregroundStyle(.secondary)
            if let message {
                Text(message).font(.callout).foregroundStyle(failed ? Color.red : Color.secondary).textSelection(.enabled)
            }
            HStack {
                if busy {
                    ProgressView().controlSize(.small)
                    Text("正在生成文件…").foregroundStyle(.secondary)
                    Button("取消导出") { exportTask?.cancel() }
                } else if !saved.isEmpty {
                    Button("在 Finder 中显示") { NSWorkspace.shared.activateFileViewerSelecting(saved) }
                }
                Spacer()
                Button("选择文件夹并导出…", action: chooseDirectory)
                    .buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
                    .disabled(busy || choosingFolder || (content == .ideas && chosenIdeas.isEmpty))
            }
        }
        .padding(24).frame(width: 640)
        .interactiveDismissDisabled(busy || choosingFolder)
    }

    private var planControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("日期范围", selection: $range) {
                ForEach(PlanRange.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            if range != .today {
                HStack(spacing: 18) {
                    labeledDate(range == .day ? "日期" : "开始", date: $start, identifier: "exportStartDate")
                    if range == .custom { labeledDate("结束", date: $end, identifier: "exportEndDate") }
                }
            }
            Text(DaylineExporter.attribution + " 包括已完成任务和无计划的日期。")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }

    private var ideaControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("范围", selection: $ideaScope) {
                ForEach(IdeaScope.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }.pickerStyle(.segmented)
            if ideaScope != .all {
                HStack {
                    TextField("搜索标题或正文", text: $query)
                    Picker("领域", selection: $areaID) {
                        Text("所有领域").tag(nil as UUID?)
                        ForEach(store.areas, id: \.id) { Text($0.name).tag(Optional($0.id)) }
                    }.frame(maxWidth: 230)
                }
                Toggle("筛选时包含已归档灵感", isOn: $includeArchived)
                if ideaScope == .selected {
                    ScrollView {
                        LazyVStack(alignment: .leading) {
                            ForEach(filteredIdeas, id: \.id) { idea in
                                Toggle(isOn: Binding(get: { selected.contains(idea.id) }, set: { value in
                                    if value { selected.insert(idea.id) } else { selected.remove(idea.id) }
                                })) { Text(idea.title.isEmpty ? "未命名灵感" : idea.title).lineLimit(2) }
                            }
                        }
                    }.frame(height: 140)
                    Text("勾选在切换筛选条件后仍会保留。") .font(.caption).foregroundStyle(.secondary)
                }
            }
            Text("将导出 \(chosenIdeas.count) 条灵感\(ideaScope == .all ? "（包含已归档）" : "")")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func labeledDate(_ title: String, date: Binding<Date>, identifier: String) -> some View {
        HStack(spacing: 8) {
            Text(title).foregroundStyle(.secondary)
            DaylineDateField(date: date, label: title, identifier: identifier, allowsClear: false)
        }
    }

    @MainActor private func documents() throws -> [ExportDocument] {
        func area(_ id: UUID?) -> String? { store.areas.first { $0.id == id }?.name }
        func goal(_ id: UUID?) -> String? { store.goals.first { $0.id == id }?.title }
        if content == .ideas {
            let values = chosenIdeas.map { ExportIdeaSnapshot(id: $0.id, title: $0.title, body: $0.body, createdAt: $0.createdAt, updatedAt: $0.updatedAt, isPinned: $0.isPinned, isArchived: $0.isArchived, area: area($0.areaID), goal: goal($0.goalID)) }
            return try DaylineExporter.documents(ideas: values, combined: combined)
        }
        let calendar = Calendar.current
        let first = range == .today ? Date() : start
        let last = range == .custom ? end : range == .seven ? calendar.date(byAdding: .day, value: 6, to: first)! : first
        let dates = try DaylineExporter.dates(from: first, through: last, calendar: calendar)
        let values = store.tasks.map { ExportTaskSnapshot(id: $0.id, title: $0.title, notes: $0.notes, scheduledDate: $0.scheduledDate, dueDate: $0.dueDate, isCompleted: $0.isCompleted, priority: $0.priorityRaw, area: area($0.areaID), goal: goal($0.goalID), sortOrder: $0.sortOrder) }
        return try DaylineExporter.documents(planTasks: values, dates: dates, combined: combined, calendar: calendar)
    }

    @MainActor private func chooseDirectory() {
        let snapshots: [ExportDocument]
        do { snapshots = try documents() }
        catch { failed = true; message = error.localizedDescription; return }
        let chosenFormat = format
        let panel = NSOpenPanel()
        panel.identifier = NSUserInterfaceItemIdentifier("Dayline.ExportDirectory")
        panel.allowedContentTypes = []
        let previousDirectory = URL(fileURLWithPath: lastExportDirectory, isDirectory: true)
        panel.directoryURL = !lastExportDirectory.isEmpty && FileManager.default.fileExists(atPath: previousDirectory.path)
            ? previousDirectory : FileManager.default.homeDirectoryForCurrentUser
        panel.title = "选择导出文件夹"; panel.prompt = "导出到此文件夹"
        panel.canChooseDirectories = true; panel.canChooseFiles = false
        panel.canCreateDirectories = true; panel.allowsMultipleSelection = false
        choosingFolder = true; saved = []; message = nil
        let completion: (NSApplication.ModalResponse) -> Void = { response in
            panel.orderOut(nil)
            choosingFolder = false
            guard response == .OK, let directory = panel.url else {
                failed = false; message = "已取消，未生成文件。"; return
            }
            lastExportDirectory = directory.path
            busy = true
            let task = Task.detached(priority: .userInitiated) {
                let access = directory.startAccessingSecurityScopedResource()
                defer { if access { directory.stopAccessingSecurityScopedResource() } }
                return try DaylineExporter.save(documents: snapshots, format: chosenFormat, directory: directory)
            }
            exportTask = task
            Task { @MainActor in
                do {
                    saved = try await task.value
                    failed = false; message = "已导出 \(saved.count) 个文件。同名文件会自动加序号，已有文件不会被覆盖。"
                } catch is CancellationError {
                    failed = false; message = "已取消，本次生成的文件已移除。"
                } catch {
                    failed = true; message = "导出失败：" + error.localizedDescription
                }
                busy = false; exportTask = nil
            }
        }
        if let window = NSApp.keyWindow { panel.beginSheetModal(for: window, completionHandler: completion) }
        else { panel.begin(completionHandler: completion) }
    }
}
