import SwiftUI
import DaylineData

private enum IdeaFilter: String, CaseIterable, Identifiable {
    case active = "灵感", pinned = "置顶", archived = "归档", all = "全部"
    var id: String { rawValue }
}

struct DaylineIdeasView: View {
    @Environment(DaylineStore.self) private var store
    let search: String
    let onExport: (Set<UUID>) -> Void

    @State private var selection: Set<UUID> = []
    @State private var filter = IdeaFilter.active
    @State private var areaFilter: UUID?
    @State private var revealedIdeaID: UUID?
    @State private var deleteIdeaID: UUID?
    @State private var convertedTaskID: UUID?
    @State private var taskEditor: TaskEditorRequest?

    private var visibleIdeas: [Idea] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return store.ideas.filter { idea in
            if idea.id == revealedIdeaID { return true }
            let matchesStatus: Bool
            switch filter {
            case .active: matchesStatus = !idea.isArchived
            case .pinned: matchesStatus = idea.isPinned && !idea.isArchived
            case .archived: matchesStatus = idea.isArchived
            case .all: matchesStatus = true
            }
            return matchesStatus && (areaFilter == nil || idea.areaID == areaFilter)
                && (query.isEmpty || idea.title.localizedStandardContains(query)
                    || idea.body.localizedStandardContains(query))
        }.sorted {
            if $0.isPinned != $1.isPinned { return $0.isPinned }
            if $0.updatedAt != $1.updatedAt { return $0.updatedAt > $1.updatedAt }
            return $0.id.uuidString < $1.id.uuidString
        }
    }

    private var selectedIdeas: [Idea] { store.ideas.filter { selection.contains($0.id) } }
    private var selectedIdea: Idea? { selectedIdeas.count == 1 ? selectedIdeas.first : nil }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("灵感").font(DaylineDesign.pageTitle)
                    Text("先留下想法，让行动慢慢成形。")
                        .font(.system(size: 13)).foregroundStyle(.secondary)
                }
                Spacer()
                Button { exportSelection() } label: { Label("导出", systemImage: "square.and.arrow.up") }
                    .buttonStyle(DaylineQuietButtonStyle())
                    .disabled(selectedIdeas.isEmpty).help("导出选中的灵感")
                    .accessibilityIdentifier("ideasExportButton")
                Button(action: addIdea) { Label("新灵感", systemImage: "square.and.pencil") }
                    .buttonStyle(DaylineQuietButtonStyle())
                    .accessibilityIdentifier("ideasAddButton")
            }.padding(.horizontal, 30).padding(.top, 30).padding(.bottom, 23)
            Divider()
            HSplitView {
                ideaList.frame(minWidth: 220, idealWidth: 250, maxWidth: 300)
                Group {
                    if let idea = selectedIdea {
                        IdeaDetailEditor(idea: idea, onConvert: { convert(idea) },
                                         onExport: { onExport([idea.id]) },
                                         onDelete: { deleteIdeaID = idea.id })
                            .id(idea.id)
                    } else if selectedIdeas.count > 1 {
                        multipleSelection
                    } else {
                        QuietEmptyState(symbol: "lightbulb", title: "给想法留一点空间",
                                        detail: "选择一条灵感继续写，或记录一个新想法。",
                                        actionTitle: "新建灵感", action: addIdea)
                    }
                }.frame(minWidth: 230, maxWidth: .infinity, maxHeight: .infinity)
            }.frame(maxHeight: .infinity)
            if let error = store.errorMessage {
                Divider()
                Label(error, systemImage: "exclamationmark.circle")
                    .font(.system(size: 12)).foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(14)
            }
            if let taskID = convertedTaskID {
                Divider()
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    Text("已创建任务，原灵感已保留。")
                    Spacer()
                    if let task = store.tasks.first(where: { $0.id == taskID }) {
                        Button("编辑任务") { taskEditor = TaskEditorRequest(task: task) }.buttonStyle(.borderless)
                    }
                    Button { convertedTaskID = nil } label: { Image(systemName: "xmark") }
                        .buttonStyle(.plain).help("关闭提示")
                }.font(.system(size: 12)).padding(.horizontal, 20).padding(.vertical, 12).background(.bar)
            }
        }.background(DaylineDesign.canvas)
            .onChange(of: search) { _, _ in resetVisibleSelection() }
            .onChange(of: filter) { _, _ in resetVisibleSelection() }
            .onChange(of: areaFilter) { _, _ in resetVisibleSelection() }
            .onChange(of: store.ideas.map(\.id)) { _, ids in selection.formIntersection(Set(ids)) }
            .confirmationDialog("删除这条灵感？", isPresented: Binding(
                get: { deleteIdeaID != nil }, set: { if !$0 { deleteIdeaID = nil } }
            ), titleVisibility: .visible) {
                Button("删除灵感", role: .destructive) {
                    if let idea = store.ideas.first(where: { $0.id == deleteIdeaID }) { store.deleteIdea(idea) }
                    deleteIdeaID = nil
                }
                Button("取消", role: .cancel) { deleteIdeaID = nil }
            } message: { Text("删除后无法撤销。已从这条灵感生成的任务会保留。") }
            .sheet(item: $taskEditor) { request in DaylineTaskEditor(request: request).environment(store) }
    }

    private var ideaList: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                ViewThatFits(in: .horizontal) {
                    ideaFilterPicker.controlSize(.large).fixedSize()
                    ideaFilterPicker.controlSize(.regular)
                }
                HStack {
                    Menu {
                        Button { areaFilter = nil } label: {
                            if areaFilter == nil { Label("所有领域", systemImage: "checkmark") }
                            else { Text("所有领域") }
                        }
                        Divider()
                        ForEach(store.areas, id: \.id) { area in
                            Button { areaFilter = area.id } label: {
                                Label(area.name, systemImage: areaFilter == area.id ? "checkmark" : area.symbol)
                            }
                        }
                    } label: {
                        DaylineMenuLabel(title: store.areas.first(where: { $0.id == areaFilter })?.name ?? "所有领域", symbol: "line.3.horizontal.decrease")
                    }
                    .menuStyle(.button).buttonStyle(.plain).menuIndicator(.hidden).fixedSize()
                    .accessibilityLabel("领域筛选")
                    .accessibilityValue(store.areas.first(where: { $0.id == areaFilter })?.name ?? "所有领域")
                    Spacer(minLength: 0)
                }
            }.padding(14)
            Divider()
            if visibleIdeas.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: search.isEmpty ? "note.text" : "magnifyingglass")
                        .font(.system(size: 25, weight: .light)).foregroundStyle(.tertiary)
                    Text(search.isEmpty ? "这里还没有灵感" : "没有匹配的灵感")
                        .font(.system(size: 13)).foregroundStyle(.secondary)
                    if !search.isEmpty { Text("试试其他关键词或筛选条件。").font(.system(size: 11)).foregroundStyle(.tertiary) }
                }.padding(.horizontal, 16)
                Spacer()
            } else {
                List(selection: $selection) {
                    ForEach(visibleIdeas, id: \.id) { idea in
                        ideaRow(idea).tag(idea.id).contextMenu {
                            Button(idea.isPinned ? "取消置顶" : "置顶", systemImage: idea.isPinned ? "pin.slash" : "pin") {
                                store.setIdeaPinned(idea, to: !idea.isPinned)
                            }
                            Button(idea.isArchived ? "移出归档" : "归档", systemImage: "archivebox") {
                                revealedIdeaID = nil
                                store.setIdeaArchived(idea, to: !idea.isArchived)
                            }
                            Divider()
                            Button("转为任务", systemImage: "checklist") { convert(idea) }
                            Button("导出这条灵感…", systemImage: "square.and.arrow.up") { onExport([idea.id]) }
                            Divider()
                            Button("删除灵感…", systemImage: "trash", role: .destructive) { deleteIdeaID = idea.id }
                        }
                    }
                }.listStyle(.inset).scrollContentBackground(.hidden)
                    .accessibilityIdentifier("ideasList")
            }
            Divider()
            HStack {
                Text("\(visibleIdeas.count) 条")
                Spacer()
                Text("⌘ 点选多条以导出")
            }.font(.system(size: 10)).foregroundStyle(.tertiary).padding(12)
        }
    }

    private var ideaFilterPicker: some View {
        Picker("灵感筛选", selection: $filter) {
            ForEach(IdeaFilter.allCases) { value in Text(value.rawValue).tag(value) }
        }.pickerStyle(.segmented).labelsHidden()
    }

    private func ideaRow(_ idea: Idea) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                if idea.isPinned { Image(systemName: "pin.fill").font(.system(size: 10)).foregroundStyle(DaylineDesign.accent) }
                Text(idea.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "未命名灵感" : idea.title)
                    .font(.system(size: 13, weight: .medium)).lineLimit(1)
                Spacer(minLength: 0)
                if idea.isArchived { Image(systemName: "archivebox").font(.system(size: 10)).foregroundStyle(.secondary) }
            }
            Text(idea.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "还没有正文" : idea.body)
                .font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(2)
            HStack(spacing: 5) {
                Text(idea.updatedAt, format: .dateTime.month().day())
                if let area = store.areas.first(where: { $0.id == idea.areaID }) {
                    Text("·")
                    Text(area.name).lineLimit(1)
                }
            }.font(.system(size: 10)).foregroundStyle(.tertiary)
        }.padding(.vertical, 9)
    }

    private var multipleSelection: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.stack").font(.system(size: 32, weight: .ultraLight)).foregroundStyle(DaylineDesign.accent)
            Text("已选择 \(selectedIdeas.count) 条灵感").font(.system(size: 18, weight: .medium))
            Text("一起导出，整理成一份文档。").font(.system(size: 13)).foregroundStyle(.secondary)
            Button("导出所选灵感…", action: exportSelection)
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func addIdea() {
        guard let idea = store.addIdea(title: "", areaID: areaFilter) else { return }
        revealedIdeaID = idea.id
        selection = [idea.id]
    }

    private func resetVisibleSelection() {
        revealedIdeaID = nil
        selection.formIntersection(Set(visibleIdeas.map(\.id)))
    }

    private func exportSelection() {
        let ids = Set(selectedIdeas.map(\.id))
        if !ids.isEmpty { onExport(ids) }
    }

    private func convert(_ idea: Idea) {
        if let task = store.taskFromIdea(idea) { convertedTaskID = task.id }
    }
}

private struct IdeaDetailEditor: View {
    @Environment(DaylineStore.self) private var store
    let idea: Idea
    let onConvert: () -> Void
    let onExport: () -> Void
    let onDelete: () -> Void
    @FocusState private var titleFocused: Bool

    private var titleBinding: Binding<String> {
        Binding(get: { idea.title }, set: { persist(title: $0, body: idea.body, areaID: idea.areaID, goalID: idea.goalID) })
    }
    private var bodyBinding: Binding<String> {
        Binding(get: { idea.body }, set: { persist(title: idea.title, body: $0, areaID: idea.areaID, goalID: idea.goalID) })
    }
    private var areaBinding: Binding<UUID?> {
        Binding(get: { idea.areaID }, set: { id in
            let linkedGoal = store.goals.first { $0.id == idea.goalID }
            let goalID = linkedGoal?.areaID != nil && linkedGoal?.areaID != id ? nil : idea.goalID
            persist(title: idea.title, body: idea.body, areaID: id, goalID: goalID)
        })
    }
    private var goalBinding: Binding<UUID?> {
        Binding(get: { idea.goalID }, set: { id in
            let areaID = store.goals.first(where: { $0.id == id }).map(\.areaID) ?? idea.areaID
            persist(title: idea.title, body: idea.body, areaID: areaID, goalID: id)
        })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 15) {
                Text(idea.isArchived ? "已归档" : "随手记")
                    .font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                Spacer()
                Button { store.setIdeaPinned(idea, to: !idea.isPinned) } label: {
                    Image(systemName: idea.isPinned ? "pin.fill" : "pin")
                        .foregroundStyle(idea.isPinned ? DaylineDesign.accent : Color.secondary)
                }.help(idea.isPinned ? "取消置顶" : "置顶")
                Button { store.setIdeaArchived(idea, to: !idea.isArchived) } label: {
                    Image(systemName: idea.isArchived ? "arrow.uturn.backward" : "archivebox")
                }.help(idea.isArchived ? "移出归档" : "归档")
                Menu {
                    Button("转为任务", systemImage: "checklist", action: onConvert)
                    Button("导出灵感…", systemImage: "square.and.arrow.up", action: onExport)
                    Divider()
                    Button("删除灵感…", systemImage: "trash", role: .destructive, action: onDelete)
                } label: { Image(systemName: "ellipsis.circle") }
                    .menuStyle(.borderlessButton).fixedSize().help("灵感操作")
            }.buttonStyle(.plain).padding(.bottom, 22)
            TextField("未命名灵感", text: titleBinding, axis: .vertical)
                .textFieldStyle(.plain).font(.system(size: 25, weight: .semibold)).lineLimit(1...4)
                .focused($titleFocused)
                .accessibilityIdentifier("ideaTitleField").padding(.bottom, 16)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 18) { areaPicker; goalPicker }
                VStack(alignment: .leading, spacing: 10) { areaPicker; goalPicker }
            }.font(.system(size: 11)).padding(.bottom, 18)
            Divider()
            TextEditor(text: bodyBinding)
                .font(.system(size: 14)).lineSpacing(6)
                .scrollContentBackground(.hidden)
                .accessibilityLabel("灵感正文").accessibilityIdentifier("ideaBodyEditor")
                .overlay(alignment: .topLeading) {
                    if idea.body.isEmpty {
                        Text("写下想法、片段，或暂时没有答案的问题…")
                            .font(.system(size: 14)).foregroundStyle(.tertiary)
                            .padding(.top, 1).padding(.leading, 5).allowsHitTesting(false)
                    }
                }.padding(.vertical, 16)
            Divider()
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(store.errorMessage == nil ? "已自动保存" : "保存失败，请重试")
                    Text(idea.updatedAt, format: .dateTime.month().day().hour().minute())
                }.font(.system(size: 10)).foregroundStyle(.secondary)
                Spacer()
                Button(action: onConvert) { Label("转为任务", systemImage: "checklist") }
                    .buttonStyle(DaylineQuietButtonStyle())
                    .help("创建待安排任务，保留原灵感及领域、目标关联")
                    .accessibilityIdentifier("ideaConvertButton")
            }.padding(.top, 15)
        }.padding(26)
            .onAppear { if idea.title.isEmpty && idea.body.isEmpty { titleFocused = true } }
    }

    private var areaPicker: some View {
        Menu {
            Button { areaBinding.wrappedValue = nil } label: {
                if idea.areaID == nil { Label("未分类", systemImage: "checkmark") }
                else { Text("未分类") }
            }
            ForEach(store.areas, id: \.id) { area in
                Button { areaBinding.wrappedValue = area.id } label: {
                    Label(area.name, systemImage: area.id == idea.areaID ? "checkmark" : area.symbol)
                }
            }
        } label: {
            DaylineMenuLabel(title: store.areas.first(where: { $0.id == idea.areaID })?.name ?? "未分类", symbol: "square.grid.2x2", caption: "领域")
        }.menuStyle(.button).buttonStyle(.plain).menuIndicator(.hidden).fixedSize()
            .accessibilityLabel("领域")
            .accessibilityValue(store.areas.first(where: { $0.id == idea.areaID })?.name ?? "未分类")
    }

    private var goalPicker: some View {
        Menu {
            Button { goalBinding.wrappedValue = nil } label: {
                if idea.goalID == nil { Label("不关联目标", systemImage: "checkmark") }
                else { Text("不关联目标") }
            }
            ForEach(store.goals.filter { $0.status == .active || $0.id == idea.goalID }, id: \.id) { goal in
                Button { goalBinding.wrappedValue = goal.id } label: {
                    if goal.id == idea.goalID { Label(goal.title, systemImage: "checkmark") }
                    else { Text(goal.title) }
                }
            }
        } label: {
            DaylineMenuLabel(title: store.goals.first(where: { $0.id == idea.goalID })?.title ?? "不关联目标", symbol: "scope", caption: "目标")
        }.menuStyle(.button).buttonStyle(.plain).menuIndicator(.hidden).fixedSize()
            .accessibilityLabel("目标")
            .accessibilityValue(store.goals.first(where: { $0.id == idea.goalID })?.title ?? "不关联目标")
    }

    private func persist(title: String, body: String, areaID: UUID?, goalID: UUID?) {
        // Commit in the control's setter, including the final keystroke before switching or quitting.
        // No delayed draft or onDisappear save can race with application termination.
        store.updateIdea(idea, title: title, body: body, areaID: areaID, goalID: goalID)
    }
}
