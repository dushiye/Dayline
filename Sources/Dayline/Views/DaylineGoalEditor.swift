import SwiftUI

struct DaylineGoalEditor: View {
    @Environment(DaylineStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let request: GoalEditorRequest
    @State private var title = ""
    @State private var notes = ""
    @State private var kind = GoalKind.longTerm
    @State private var status = GoalStatus.active
    @State private var areaID: UUID?
    @State private var parentGoalID: UUID?
    @State private var progress = 0.0
    @State private var hasTarget = false
    @State private var targetDate = Date.now
    @State private var didLoad = false
    @State private var showDeleteConfirmation = false
    @State private var taskEditor: TaskEditorRequest?
    @FocusState private var titleFocused: Bool

    private var canSave: Bool { !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private var parents: [Goal] { store.goals.filter { $0.kind == .longTerm && $0.id != request.goal?.id && ($0.status == .active || $0.id == parentGoalID) } }
    private var actions: [DayTask] { guard let goal = request.goal else { return [] }; return store.tasks.filter { $0.goalID == goal.id }.sorted { $0.sortOrder < $1.sortOrder } }
    private var hasChildren: Bool { guard let goal = request.goal else { return false }; return store.goals.contains { $0.parentGoalID == goal.id } }

    private var hasLinkedActions: Bool { !actions.isEmpty }
    private var areaLocked: Bool { request.goal != nil && (hasChildren || hasLinkedActions) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(request.goal == nil ? "新建目标" : "编辑目标").font(.system(size: 14, weight: .semibold))
                Spacer()
                Text("DIRECTION → OUTCOME").font(.system(size: 9, weight: .medium)).tracking(1.5).foregroundStyle(.tertiary)
            }.padding(.horizontal, 28).padding(.top, 24).padding(.bottom, 24)
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    TextField("你想实现什么？", text: $title, axis: .vertical)
                        .font(.system(size: 23, weight: .medium)).textFieldStyle(.plain).lineLimit(1...3).focused($titleFocused)
                        .accessibilityIdentifier("goalTitleField")
                    TextField("写下成功的标准，而不只是要做的事情…", text: $notes, axis: .vertical)
                        .textFieldStyle(.plain).font(.system(size: 13)).lineLimit(3...7).foregroundStyle(.secondary)
                    Divider()
                    Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 17) {
                        GridRow {
                            Text("目标类型").foregroundStyle(.secondary).frame(width: 85, alignment: .leading)
                            Picker("目标类型", selection: $kind) {
                                Text("长期方向").tag(GoalKind.longTerm)
                                Text("短期成果").tag(GoalKind.shortTerm)
                            }.labelsHidden().pickerStyle(.segmented).disabled(hasChildren)
                        }
                        if kind == .shortTerm {
                            GridRow {
                                Text("上级目标").foregroundStyle(.secondary)
                                Picker("上级目标", selection: $parentGoalID) {
                                    Text("独立目标").tag(Optional<UUID>.none)
                                    ForEach(parents.filter { !areaLocked || $0.areaID == nil || $0.areaID == areaID }, id: \.id) { goal in Text(goal.title).tag(Optional(goal.id)) }
                                }.labelsHidden()
                            }
                        }
                        GridRow {
                            Text("所属领域").foregroundStyle(.secondary)
                            Picker("所属领域", selection: $areaID) {
                                Text("未分类").tag(Optional<UUID>.none)
                                ForEach(store.areas, id: \.id) { area in Text(area.name).tag(Optional(area.id)) }
                            }.labelsHidden().disabled(areaLocked)
                        }
                        GridRow {
                            Text("目标日期").foregroundStyle(.secondary)
                            HStack(spacing: 12) {
                                Toggle("目标日期", isOn: $hasTarget).labelsHidden().toggleStyle(.switch).controlSize(.small)
                                    .accessibilityLabel("启用目标日期")
                                    .accessibilityIdentifier("goalTargetDateToggle")
                                if hasTarget {
                                    DaylineDateField(date: $targetDate, label: "目标日期") { hasTarget = false }
                                } else {
                                    Text("不限日期").foregroundStyle(.tertiary)
                                }
                                Spacer()
                            }
                        }
                        GridRow {
                            Text("状态").foregroundStyle(.secondary)
                            Picker("状态", selection: $status) {
                                Text("进行中").tag(GoalStatus.active)
                                Text("已完成").tag(GoalStatus.completed)
                                Text("已归档").tag(GoalStatus.archived)
                            }.labelsHidden()
                        }
                    }.font(.system(size: 12))
                    if areaLocked {
                        Text("此目标已有关联行动或子目标。如需更改领域，请先解除这些关联。")
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    if hasChildren {
                        Text("此目标已有短期子目标。移除子目标关联后，可以更改目标类型。")
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    Divider()
                    VStack(alignment: .leading, spacing: 9) {
                        HStack {
                            Text("成果进度").font(.system(size: 12, weight: .semibold))
                            Spacer()
                            Text("\(Int(progress * 100))%").font(.system(size: 16, weight: .medium, design: .rounded)).monospacedDigit().foregroundStyle(DaylineDesign.accent)
                        }
                        Slider(value: $progress, in: 0...1, step: 0.05).accessibilityLabel("成果进度")
                        Text("由你根据实际成果更新。完成任务不会自动改变这个百分比。")
                            .font(.system(size: 11)).foregroundStyle(.secondary).lineSpacing(3)
                    }
                    if request.goal != nil {
                        Divider()
                        HStack {
                            Text("关联行动").font(.system(size: 12, weight: .semibold))
                            Text("\(actions.filter(\.isCompleted).count) / \(actions.count) 已完成").font(.system(size: 11)).foregroundStyle(.secondary)
                            Spacer()
                            Button { save(close: false); if store.errorMessage == nil, let goal = request.goal { taskEditor = TaskEditorRequest(areaID: areaID, goalID: goal.id) } } label: { Label("添加", systemImage: "plus") }.buttonStyle(.borderless).font(.system(size: 12)).disabled(!canSave)
                        }
                        if actions.isEmpty {
                            Text("还没有关联行动。把目标拆成一个可以开始的小步骤。")
                                .font(.system(size: 12)).foregroundStyle(.secondary).padding(.vertical, 5)
                        } else {
                            VStack(spacing: 0) {
                                ForEach(actions, id: \.id) { task in
                                    DaylineTaskRow(task: task, area: nil, goal: nil, carryover: false, onToggle: { store.toggleTask(task) }, onEdit: { taskEditor = TaskEditorRequest(task: task) }, onToday: { store.reschedule(task, to: .now) })
                                }
                            }
                        }
                    }
                }.padding(.horizontal, 28).padding(.bottom, 25)
            }
            if let error = store.errorMessage {
                Text(error).font(.system(size: 11)).foregroundStyle(.red).padding(.horizontal, 28).padding(.bottom, 10)
            }
            Divider()
            HStack {
                if request.goal != nil {
                    Button(role: .destructive) { showDeleteConfirmation = true } label: { Image(systemName: "trash") }.buttonStyle(.borderless).help("删除目标")
                }
                Spacer()
                Button("取消") { dismiss() }.keyboardShortcut(.cancelAction)
                Button(request.goal == nil ? "创建目标" : "保存") { save() }
                    .buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction).disabled(!canSave)
                    .accessibilityIdentifier("goalSaveButton")
            }.padding(.horizontal, 28).padding(.vertical, 18)
        }.frame(width: 570, height: 650)
            .onAppear {
                guard !didLoad else { return }; didLoad = true
                title = request.goal?.title ?? ""; notes = request.goal?.notes ?? ""
                kind = request.goal?.kind ?? (request.parentGoalID != nil ? .shortTerm : .longTerm)
                status = request.goal?.status ?? .active
                areaID = request.goal?.areaID ?? request.areaID
                parentGoalID = request.goal?.parentGoalID ?? request.parentGoalID
                progress = request.goal?.progress ?? 0
                hasTarget = request.goal?.targetDate != nil; targetDate = request.goal?.targetDate ?? .now
                titleFocused = true
            }
            .onChange(of: kind) { _, value in if value == .longTerm { parentGoalID = nil } }
            .onChange(of: parentGoalID) { _, value in
                if let parent = parents.first(where: { $0.id == value }), !areaLocked { areaID = parent.areaID }
            }
            .onChange(of: areaID) { _, value in
                if let parent = parents.first(where: { $0.id == parentGoalID }), let parentArea = parent.areaID, parentArea != value { parentGoalID = nil }
            }
            .sheet(item: $taskEditor) { request in DaylineTaskEditor(request: request).environment(store) }
            .confirmationDialog("删除这个目标？", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                Button("删除目标", role: .destructive) { if let goal = request.goal { store.deleteGoal(goal) }; dismiss() }
                Button("取消", role: .cancel) { }
            } message: { Text("关联任务和子目标会保留，它们与这个目标的关联会解除。") }
    }

    private func save(close: Bool = true) {
        guard canSave else { return }
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let goal = request.goal else {
            if store.addGoal(title: cleanTitle, kind: kind, areaID: areaID,
                             parentGoalID: kind == .shortTerm ? parentGoalID : nil, notes: notes,
                             targetDate: hasTarget ? targetDate : nil, progress: progress, status: status) != nil,
               close { dismiss() }
            return
        }
        goal.title = cleanTitle
        goal.notes = notes
        goal.kind = kind
        goal.areaID = areaID
        goal.parentGoalID = kind == .shortTerm ? parentGoalID : nil
        goal.targetDate = hasTarget ? targetDate : nil
        goal.progress = progress
        store.setGoalStatus(goal, to: status)
        if close && store.errorMessage == nil { dismiss() }
    }
}
