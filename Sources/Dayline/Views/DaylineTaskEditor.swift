import SwiftUI

struct DaylineTaskEditor: View {
    @Environment(DaylineStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let request: TaskEditorRequest
    @State private var title = ""
    @State private var notes = ""
    @State private var areaID: UUID?
    @State private var goalID: UUID?
    @State private var hasSchedule = false
    @State private var scheduledDate = Date.now
    @State private var hasDueDate = false
    @State private var dueDate = Date.now
    @State private var priority = TaskPriority.none
    @State private var repeatRule = RepeatRule.none
    @State private var showDeleteConfirmation = false
    @FocusState private var titleFocused: Bool
    @State private var didLoad = false

    private var canSave: Bool { !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private var selectableGoals: [Goal] {
        store.goals.filter { $0.status == .active || $0.id == goalID }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(request.task == nil ? "新建任务" : "编辑任务").font(.system(size: 14, weight: .semibold))
                Spacer()
                Text("ACTION").font(.system(size: 9, weight: .medium)).tracking(2).foregroundStyle(.tertiary)
            }.padding(.horizontal, 28).padding(.top, 24).padding(.bottom, 24)
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    TextField("想做什么？", text: $title, axis: .vertical)
                        .font(.system(size: 23, weight: .medium)).textFieldStyle(.plain)
                        .lineLimit(1...3).focused($titleFocused)
                        .accessibilityIdentifier("taskTitleField")
                    TextField("添加备注、下一步或相关链接…", text: $notes, axis: .vertical)
                        .textFieldStyle(.plain).font(.system(size: 13)).lineLimit(3...8)
                        .foregroundStyle(.secondary).accessibilityIdentifier("taskNotesField")
                    Divider()
                    Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 17) {
                        GridRow {
                            editorLabel("计划日期", symbol: "calendar")
                            HStack(spacing: 12) {
                                Toggle("安排时间", isOn: $hasSchedule).labelsHidden().toggleStyle(.switch).controlSize(.small)
                                    .accessibilityLabel("启用计划日期")
                                if hasSchedule { DatePicker("计划日期", selection: $scheduledDate, displayedComponents: .date).labelsHidden() }
                                else { Text("暂不安排").foregroundStyle(.tertiary) }
                                Spacer()
                                Button("今天") { hasSchedule = true; scheduledDate = .now }.buttonStyle(.borderless)
                                Button("明天") { hasSchedule = true; scheduledDate = Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now }.buttonStyle(.borderless)
                            }
                        }
                        GridRow {
                            editorLabel("截止日期", symbol: "flag")
                            HStack(spacing: 12) {
                                Toggle("设定截止", isOn: $hasDueDate).labelsHidden().toggleStyle(.switch).controlSize(.small)
                                    .accessibilityLabel("启用截止日期")
                                if hasDueDate { DatePicker("截止日期", selection: $dueDate, displayedComponents: .date).labelsHidden() }
                                else { Text("没有硬性截止").foregroundStyle(.tertiary) }
                                Spacer()
                            }
                        }
                        GridRow {
                            editorLabel("领域", symbol: "square.grid.2x2")
                            Picker("领域", selection: $areaID) {
                                Text("未分类").tag(Optional<UUID>.none)
                                ForEach(store.areas, id: \.id) { area in Text(area.name).tag(Optional(area.id)) }
                            }.labelsHidden()
                        }
                        GridRow {
                            editorLabel("关联目标", symbol: "scope")
                            Picker("关联目标", selection: $goalID) {
                                Text("不关联目标").tag(Optional<UUID>.none)
                                ForEach(selectableGoals, id: \.id) { goal in Text(goal.title).tag(Optional(goal.id)) }
                            }.labelsHidden()
                        }
                        GridRow {
                            editorLabel("优先级", symbol: "exclamationmark")
                            Picker("优先级", selection: $priority) {
                                ForEach(TaskPriority.allCases, id: \.self) { value in Text(value.label).tag(value) }
                            }.labelsHidden().pickerStyle(.segmented)
                        }
                        GridRow {
                            editorLabel("重复", symbol: "repeat")
                            Picker("重复", selection: $repeatRule) {
                                ForEach(RepeatRule.allCases, id: \.self) { value in Text(value.label).tag(value) }
                            }.labelsHidden()
                        }
                    }.font(.system(size: 12))
                    if repeatRule != .none {
                        Text("完成后自动生成下一次行动。撤销完成会保留下一次行动，再次完成不会重复生成。")
                            .font(.system(size: 11)).foregroundStyle(.secondary).lineSpacing(3)
                    }
                    if let task = request.task, task.isCompleted {
                        Label("这项任务已完成", systemImage: "checkmark.circle.fill").font(.system(size: 12)).foregroundStyle(.green)
                    }
                }.padding(.horizontal, 28).padding(.bottom, 25)
            }
            if let error = store.errorMessage {
                Text(error).font(.system(size: 11)).foregroundStyle(.red).padding(.horizontal, 28).padding(.bottom, 10)
            }
            Divider()
            HStack {
                if request.task != nil {
                    Button(role: .destructive) { showDeleteConfirmation = true } label: { Image(systemName: "trash") }
                        .buttonStyle(.borderless).help("删除任务")
                }
                Spacer()
                Button("取消") { dismiss() }.keyboardShortcut(.cancelAction)
                Button(request.task == nil ? "添加任务" : "保存") { save() }
                    .buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction).disabled(!canSave)
                    .accessibilityIdentifier("taskSaveButton")
            }.padding(.horizontal, 28).padding(.vertical, 18)
        }.frame(width: 570, height: 570)
            .onAppear {
                guard !didLoad else { return }
                didLoad = true
                title = request.task?.title ?? ""
                notes = request.task?.notes ?? ""
                areaID = request.task?.areaID ?? request.areaID
                goalID = request.task?.goalID ?? request.goalID
                let schedule = request.task != nil ? request.task?.scheduledDate : request.scheduledDate
                hasSchedule = schedule != nil; scheduledDate = schedule ?? .now
                hasDueDate = request.task?.dueDate != nil; dueDate = request.task?.dueDate ?? .now
                priority = request.task?.priority ?? .none
                repeatRule = request.task?.repeatRule ?? .none
                titleFocused = true
            }
            .onChange(of: goalID) { _, id in
                if let goal = store.goals.first(where: { $0.id == id }) { areaID = goal.areaID }
            }
            .onChange(of: areaID) { _, id in
                if let goal = store.goals.first(where: { $0.id == goalID }), let goalArea = goal.areaID, goalArea != id { goalID = nil }
            }
            .confirmationDialog("删除这项任务？", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                Button("删除任务", role: .destructive) { if let task = request.task { store.deleteTask(task) }; dismiss() }
                Button("取消", role: .cancel) { }
            } message: { Text("删除后无法撤销。") }
    }

    private func editorLabel(_ text: String, symbol: String) -> some View {
        Label(text, systemImage: symbol).foregroundStyle(.secondary).frame(width: 95, alignment: .leading)
    }
    private func save() {
        guard canSave else { return }
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let task = request.task else {
            if store.addTask(title: cleanTitle, areaID: areaID, scheduledDate: hasSchedule ? scheduledDate : nil,
                             dueDate: hasDueDate ? dueDate : nil, goalID: goalID,
                             notes: notes, priority: priority, repeatRule: repeatRule) != nil { dismiss() }
            return
        }
        task.title = cleanTitle
        task.notes = notes
        task.areaID = areaID
        task.goalID = goalID
        task.scheduledDate = hasSchedule ? scheduledDate : nil
        task.dueDate = hasDueDate ? dueDate : nil
        task.priority = priority
        task.repeatRule = repeatRule
        store.save()
        if store.errorMessage == nil { dismiss() }
    }
}
