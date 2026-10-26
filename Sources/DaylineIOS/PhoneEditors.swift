import SwiftUI
import DaylineCore
import DaylineData

struct PhoneTaskRequest: Identifiable {
    let id = UUID()
    var task: DayTask?
    var scheduledDate: Date?
    var areaID: UUID?
    var goalID: UUID?
}

struct PhoneGoalRequest: Identifiable {
    let id = UUID()
    var goal: Goal?
    var areaID: UUID?
    var parentGoalID: UUID?
}

struct PhoneTaskEditor: View {
    @Environment(DaylineStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let request: PhoneTaskRequest

    @State private var title = ""
    @State private var notes = ""
    @State private var areaID: UUID?
    @State private var goalID: UUID?
    @State private var hasSchedule = false
    @State private var scheduledDate = Calendar.current.startOfDay(for: Date())
    @State private var hasDueDate = false
    @State private var dueDate = Calendar.current.startOfDay(for: Date())
    @State private var priority = TaskPriority.none
    @State private var repeatRule = RepeatRule.none
    @State private var pickingSchedule = false
    @State private var pickingDue = false
    @State private var confirmDelete = false

    private var canSave: Bool { !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private var goals: [Goal] {
        store.goals.filter { goal in
            goal.status != .archived && (areaID == nil || goal.areaID == nil || goal.areaID == areaID)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("想做什么？", text: $title, axis: .vertical)
                        .font(.title3.weight(.medium))
                    TextField("备注", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
                Section("时间") {
                    Toggle("安排日期", isOn: $hasSchedule)
                    if hasSchedule {
                        Button { pickingSchedule = true } label: {
                            LabeledContent("计划") { Text(scheduledDate.formatted(.dateTime.month().day().weekday(.abbreviated))) }
                        }
                        .foregroundStyle(.primary)
                    }
                    Toggle("截止日期", isOn: $hasDueDate)
                    if hasDueDate {
                        Button { pickingDue = true } label: {
                            LabeledContent("截止") { Text(dueDate.formatted(.dateTime.month().day().weekday(.abbreviated))) }
                        }
                        .foregroundStyle(.primary)
                    }
                    Picker("重复", selection: $repeatRule) {
                        ForEach(RepeatRule.allCases, id: \.self) { Text($0.phoneLabel).tag($0) }
                    }
                }
                Section("归属") {
                    Picker("领域", selection: $areaID) {
                        Text("无").tag(UUID?.none)
                        ForEach(store.areas, id: \.id) { Text($0.name).tag(Optional($0.id)) }
                    }
                    Picker("目标", selection: $goalID) {
                        Text("无").tag(UUID?.none)
                        ForEach(goals, id: \.id) { Text($0.title).tag(Optional($0.id)) }
                    }
                    Picker("优先级", selection: $priority) {
                        ForEach(TaskPriority.allCases, id: \.self) { Text($0.phoneLabel).tag($0) }
                    }
                }
                if request.task != nil {
                    Section {
                        Button("删除任务", role: .destructive) { confirmDelete = true }
                    }
                }
            }
            .navigationTitle(request.task == nil ? "新任务" : "编辑任务")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("保存") { save() }.disabled(!canSave) }
            }
            .onAppear(perform: load)
            .onChange(of: goalID) { _, id in
                if let goal = store.goals.first(where: { $0.id == id }) { areaID = goal.areaID }
            }
            .onChange(of: areaID) { _, id in
                if let goal = store.goals.first(where: { $0.id == goalID }), let goalArea = goal.areaID, goalArea != id { goalID = nil }
            }
            .sheet(isPresented: $pickingSchedule) {
                PhoneDateSheet(date: $scheduledDate) { hasSchedule = false; pickingSchedule = false }
            }
            .sheet(isPresented: $pickingDue) {
                PhoneDateSheet(date: $dueDate) { hasDueDate = false; pickingDue = false }
            }
            .confirmationDialog("删除这项任务？", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("删除任务", role: .destructive) { if let task = request.task { store.deleteTask(task) }; dismiss() }
                Button("取消", role: .cancel) {}
            }
        }
        .presentationDetents([.large])
    }

    private func load() {
        title = request.task?.title ?? ""
        notes = request.task?.notes ?? ""
        areaID = request.task?.areaID ?? request.areaID
        goalID = request.task?.goalID ?? request.goalID
        if let date = request.task?.scheduledDate ?? request.scheduledDate {
            hasSchedule = request.task?.scheduledDate != nil || request.task == nil
            scheduledDate = Calendar.current.startOfDay(for: date)
        }
        if let date = request.task?.dueDate {
            hasDueDate = true
            dueDate = Calendar.current.startOfDay(for: date)
        }
        priority = request.task?.priority ?? .none
        repeatRule = request.task?.repeatRule ?? .none
    }

    private func save() {
        guard canSave else { return }
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let schedule = hasSchedule ? scheduledDate : nil
        let due = hasDueDate ? dueDate : nil
        guard let original = request.task else {
            if store.addTask(title: clean, areaID: areaID, scheduledDate: schedule, dueDate: due, goalID: goalID, notes: notes, priority: priority, repeatRule: repeatRule) != nil {
                dismiss()
            }
            return
        }
        guard let task = store.tasks.first(where: { $0.id == original.id }) else { return }
        task.title = clean
        task.notes = notes
        task.areaID = areaID
        task.goalID = goalID
        task.scheduledDate = schedule
        task.dueDate = due
        task.priority = priority
        task.repeatRule = repeatRule
        store.save()
        if store.errorMessage == nil { dismiss() }
    }
}

struct PhoneDateSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var date: Date
    var clear: () -> Void

    var body: some View {
        NavigationStack {
            DatePicker("日期", selection: $date, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .labelsHidden()
                .padding(.horizontal, 12)
                .navigationTitle("选择日期")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("清除") { clear(); dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("完成") { dismiss() }
                    }
                }
        }
        .presentationDetents([.medium, .large])
    }
}

struct PhoneGoalEditor: View {
    @Environment(DaylineStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let request: PhoneGoalRequest

    @State private var title = ""
    @State private var notes = ""
    @State private var kind = GoalKind.longTerm
    @State private var status = GoalStatus.active
    @State private var progress = 0.0
    @State private var areaID: UUID?
    @State private var parentGoalID: UUID?
    @State private var hasTarget = false
    @State private var targetDate = Calendar.current.startOfDay(for: Date())
    @State private var pickingDate = false
    @State private var confirmDelete = false

    private var canSave: Bool { !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private var parents: [Goal] {
        store.goals.filter { $0.kind == .longTerm && $0.id != request.goal?.id && ($0.status == .active || $0.id == parentGoalID) }
    }
    private var linked: [DayTask] {
        guard let id = request.goal?.id else { return [] }
        return PhoneTasks.sorted(store.tasks.filter { $0.goalID == id })
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("目标", text: $title, axis: .vertical)
                        .font(.title3.weight(.medium))
                    TextField("为什么重要", text: $notes, axis: .vertical)
                        .lineLimit(2...5)
                }
                Section {
                    Picker("类型", selection: $kind) {
                        Text("长期目标").tag(GoalKind.longTerm)
                        Text("短期目标").tag(GoalKind.shortTerm)
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    if kind == .shortTerm {
                        Picker("属于", selection: $parentGoalID) {
                            Text("无").tag(UUID?.none)
                            ForEach(parents, id: \.id) { Text($0.title).tag(Optional($0.id)) }
                        }
                    }
                    Picker("领域", selection: $areaID) {
                        Text("无").tag(UUID?.none)
                        ForEach(store.areas, id: \.id) { Text($0.name).tag(Optional($0.id)) }
                    }
                    Picker("状态", selection: $status) {
                        ForEach(GoalStatus.allCases, id: \.self) { Text($0.phoneLabel).tag($0) }
                    }
                }
                Section("进度") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(Int((progress * 100).rounded()))%")
                            .font(.title2.weight(.semibold))
                            .monospacedDigit()
                        Slider(value: $progress, in: 0...1)
                            .tint(PhoneDesign.accent)
                    }
                    Toggle("目标日期", isOn: $hasTarget)
                    if hasTarget {
                        Button { pickingDate = true } label: {
                            LabeledContent("日期") { Text(targetDate.formatted(.dateTime.year().month().day())) }
                        }
                        .foregroundStyle(.primary)
                    }
                }
                if !linked.isEmpty {
                    Section("关联任务") {
                        ForEach(linked, id: \.id) { task in
                            Label(task.title, systemImage: task.isCompleted ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(task.isCompleted ? .secondary : .primary)
                        }
                    }
                }
                if request.goal != nil {
                    Section { Button("删除目标", role: .destructive) { confirmDelete = true } }
                }
            }
            .navigationTitle(request.goal == nil ? "新目标" : "编辑目标")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("保存") { save() }.disabled(!canSave) }
            }
            .onAppear(perform: load)
            .onChange(of: kind) { _, value in if value == .longTerm { parentGoalID = nil } }
            .onChange(of: status) { _, value in if value == .completed { progress = 1 } }
            .sheet(isPresented: $pickingDate) {
                PhoneDateSheet(date: $targetDate) { hasTarget = false; pickingDate = false }
            }
            .confirmationDialog("删除这个目标？", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("删除目标", role: .destructive) { if let goal = request.goal { store.deleteGoal(goal) }; dismiss() }
                Button("取消", role: .cancel) {}
            } message: {
                Text("关联任务和子目标会保留，只是不再挂在这个目标下面。")
            }
        }
    }

    private func load() {
        title = request.goal?.title ?? ""
        notes = request.goal?.notes ?? ""
        kind = request.goal?.kind ?? (request.parentGoalID == nil ? .longTerm : .shortTerm)
        status = request.goal?.status ?? .active
        progress = request.goal?.progress ?? 0
        areaID = request.goal?.areaID ?? request.areaID
        parentGoalID = request.goal?.parentGoalID ?? request.parentGoalID
        if let date = request.goal?.targetDate {
            hasTarget = true
            targetDate = Calendar.current.startOfDay(for: date)
        }
    }

    private func save() {
        guard canSave else { return }
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let parent = kind == .shortTerm ? parentGoalID : nil
        let date = hasTarget ? targetDate : nil
        guard let original = request.goal else {
            if store.addGoal(title: clean, kind: kind, areaID: areaID, parentGoalID: parent, notes: notes, targetDate: date, progress: progress, status: status) != nil {
                dismiss()
            }
            return
        }
        guard let goal = store.goals.first(where: { $0.id == original.id }) else { return }
        goal.title = clean
        goal.notes = notes
        goal.kind = kind
        goal.areaID = areaID
        goal.parentGoalID = parent
        goal.targetDate = date
        goal.progress = progress
        store.setGoalStatus(goal, to: status)
        if store.errorMessage == nil { dismiss() }
    }
}
