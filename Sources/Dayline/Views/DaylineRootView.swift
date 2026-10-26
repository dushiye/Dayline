import SwiftUI
import Combine
import AppKit
import UniformTypeIdentifiers

private enum DaylineDestination: Hashable {
    case today, upcoming, inbox, goals, ideas, area(UUID)
}

struct TaskEditorRequest: Identifiable {
    let id = UUID()
    var task: DayTask?
    var areaID: UUID?
    var goalID: UUID?
    var scheduledDate: Date?
}

struct GoalEditorRequest: Identifiable {
    let id = UUID()
    var goal: Goal?
    var areaID: UUID?
    var parentGoalID: UUID?
}

private struct ExportRequest: Identifiable {
    let id = UUID()
    var ideaIDs: Set<UUID>? = nil
}

struct DaylineRootView: View {
    @Environment(DaylineStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selection: DaylineDestination? = .today
    @State private var search = ""
    @State private var quickTitle = ""
    @State private var currentDate = Date.now
    private let dayTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    @State private var taskEditor: TaskEditorRequest?
    @State private var goalEditor: GoalEditorRequest?
    @State private var completedExpanded = false
    @State private var selectedUpcomingDay: Date? = nil
    @State private var pendingBackup: Data?
    @State private var backupName = ""
    @State private var showRestoreConfirmation = false
    @State private var showDemoConfirmation = false
    @State private var localError: String?
    @State private var toast: String?
    @State private var undoTaskID: UUID?
    @State private var deleteTaskID: UUID?
    @State private var deleteGoalID: UUID?
    @State private var exportRequest: ExportRequest?
    @AppStorage("coachDismissedDay") private var coachDismissedDay = ""

    private var selectedArea: Area? {
        guard case .area(let id) = selection else { return nil }
        return store.areas.first { $0.id == id }
    }
    private var title: String {
        if !search.isEmpty { return "搜索" }
        switch selection ?? .today {
        case .today: return "今天"
        case .upcoming: return "即将到来"
        case .inbox: return "收件箱"
        case .goals: return "目标"
        case .ideas: return "灵感"
        case .area: return selectedArea?.name ?? "领域"
        }
    }
    private var subtitle: String {
        if !search.isEmpty { return "寻找任务、笔记与目标" }
        switch selection ?? .today {
        case .today: return currentDate.formatted(.dateTime.month(.wide).day().weekday(.wide))
        case .upcoming: return "留一点余地，安排接下来的一周。"
        case .inbox: return "先记下来，再决定何时行动。"
        case .goals: return "让今天的行动，靠近真正想要的结果。"
        case .ideas: return "留住想法，慢慢展开。"
        case .area: return "持续投入，慢慢积累。"
        }
    }
    private var sortedTasks: [DayTask] {
        store.tasks.sorted { $0.sortOrder == $1.sortOrder ? $0.createdAt < $1.createdAt : $0.sortOrder < $1.sortOrder }
    }
    private var openTasks: [DayTask] { sortedTasks.filter { !$0.isCompleted } }
    private var carriedTasks: [DayTask] { openTasks.filter { (DaylineDates.isUnfinishedPast($0) || DaylineDates.isOverdue($0)) && !DaylineDates.isToday($0) } }
    private var todayTasks: [DayTask] { openTasks.filter { DaylineDates.isToday($0) } }
    private var inboxTasks: [DayTask] { openTasks.filter { DaylineDates.isInbox($0) } }
    private var isEmptyLibrary: Bool { store.tasks.isEmpty && store.goals.isEmpty }
    private var matchingTasks: [DayTask] {
        sortedTasks.filter { matches($0.title) || matches($0.notes) }
    }
    private var matchingGoals: [Goal] {
        store.goals.filter { matches($0.title) || matches($0.notes) }
    }
    private func matches(_ text: String) -> Bool { text.localizedStandardContains(search) }

    var body: some View {
        NavigationSplitView {
            sidebar.navigationSplitViewColumnWidth(min: 205, ideal: 220, max: 260)
        } detail: {
            VStack(spacing: 0) {
                if selection == .ideas {
                    DaylineIdeasView(search: search) { ids in
                        exportRequest = ExportRequest(ideaIDs: ids)
                    }
                } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        pageHeader
                        if !search.isEmpty { searchContent }
                        else {
                            switch selection ?? .today {
                            case .today: todayContent
                            case .upcoming: upcomingContent
                            case .inbox: inboxContent
                            case .goals: goalsContent
                            case .ideas: EmptyView()
                            case .area: areaContent
                            }
                        }
                        if isEmptyLibrary && search.isEmpty {
                            HStack {
                                Spacer()
                                Button("试用示例内容") { showDemoConfirmation = true }
                                    .buttonStyle(.plain).font(.system(size: 12)).foregroundStyle(.secondary)
                                Spacer()
                            }.padding(.top, 12).padding(.bottom, 28)
                        }
                    }.frame(maxWidth: 850, alignment: .leading)
                        .padding(.horizontal, DaylineDesign.pageInset).padding(.top, 34).padding(.bottom, 40)
                        .frame(maxWidth: .infinity, alignment: .top)
                }
                }
                if let toast {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                        Text(toast).font(.system(size: 12))
                        Spacer()
                        if undoTaskID != nil {
                            Button("撤销") { undoCompletion() }.buttonStyle(.plain).foregroundStyle(DaylineDesign.accent)
                        }
                        Button { self.toast = nil; undoTaskID = nil } label: { Image(systemName: "xmark") }
                            .buttonStyle(.plain).foregroundStyle(.secondary)
                    }.padding(.horizontal, 22).padding(.vertical, 12).background(.bar)
                }
            }.background(DaylineDesign.canvas)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button { exportRequest = ExportRequest() } label: { Label("导出…", systemImage: "square.and.arrow.up") }
                            .help("导出计划或灵感（⇧⌘E）")
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button { newTask() } label: { Label("新建任务", systemImage: "plus") }
                            .help("新建任务（⌘N）")
                    }
                }
        }
        .tint(DaylineDesign.accent)
        .searchable(text: $search, placement: .sidebar, prompt: selection == .ideas ? "搜索灵感标题与正文" : "搜索任务与目标")
        .onChange(of: selection) { _, _ in completedExpanded = false; selectedUpcomingDay = nil }
        .onReceive(dayTimer) { currentDate = $0; store.runDailyBackup() }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in currentDate = .now }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didWakeNotification)) { _ in currentDate = .now }
        .onReceive(NotificationCenter.default.publisher(for: .daylineNewTask)) { _ in newTask() }
        .onReceive(NotificationCenter.default.publisher(for: .daylineExport)) { _ in exportRequest = ExportRequest() }
        .sheet(item: $exportRequest) { request in
            DaylineExportCenter(initialIdeaIDs: request.ideaIDs).environment(store)
        }
        .sheet(item: $taskEditor) { request in
            DaylineTaskEditor(request: request).environment(store)
        }
        .sheet(item: $goalEditor) { request in
            DaylineGoalEditor(request: request).environment(store)
        }
        .onAppear { openQADatePreviewIfRequested() }
        .onChange(of: store.tasks.count) { _, _ in openQADatePreviewIfRequested() }
        .onChange(of: store.goals.count) { _, _ in openQADatePreviewIfRequested() }
        .alert("无法完成操作", isPresented: Binding(get: { localError != nil || store.errorMessage != nil }, set: { if !$0 { localError = nil; store.errorMessage = nil } })) {
            Button("知道了") { localError = nil; store.errorMessage = nil }
        } message: { Text(localError ?? store.errorMessage ?? "请重试。") }
        .confirmationDialog("恢复备份？", isPresented: $showRestoreConfirmation, titleVisibility: .visible) {
            Button("替换当前数据", role: .destructive) { restoreBackup() }
            Button("取消", role: .cancel) { pendingBackup = nil }
        } message: { Text("“\(backupName)”将替换全部任务、目标、领域、灵感和计划历史。旧版备份不含灵感与历史。替换前会自动保存当前备份，此操作无法直接撤销。") }
        .confirmationDialog("添加示例内容？", isPresented: $showDemoConfirmation, titleVisibility: .visible) {
            Button("添加示例") { store.loadDemoData() }
            Button("取消", role: .cancel) { }
        } message: { Text("添加少量学习、科研和健康示例，帮助你体验任务与目标的关联。所有示例都可以编辑或删除。") }
        .confirmationDialog("删除任务？", isPresented: Binding(get: { deleteTaskID != nil }, set: { if !$0 { deleteTaskID = nil } }), titleVisibility: .visible) {
            Button("删除任务", role: .destructive) {
                if let task = store.tasks.first(where: { $0.id == deleteTaskID }) { store.deleteTask(task) }
                deleteTaskID = nil
            }
            Button("取消", role: .cancel) { deleteTaskID = nil }
        } message: { Text("删除后无法撤销。") }
        .confirmationDialog("删除目标？", isPresented: Binding(get: { deleteGoalID != nil }, set: { if !$0 { deleteGoalID = nil } }), titleVisibility: .visible) {
            Button("删除目标", role: .destructive) {
                if let goal = store.goals.first(where: { $0.id == deleteGoalID }) { store.deleteGoal(goal) }
                deleteGoalID = nil
            }
            Button("取消", role: .cancel) { deleteGoalID = nil }
        } message: { Text("关联任务与子目标会保留，目标关联会解除。") }
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "sun.horizon.fill").font(.system(size: 21, weight: .medium)).foregroundStyle(DaylineDesign.accent)
                Text("Dayline").font(.system(size: 20, weight: .semibold, design: .rounded))
                Spacer()
            }.padding(.horizontal, 22).padding(.top, 24).padding(.bottom, 20)
            List(selection: $selection) {
                Section {
                    navRow("今天", symbol: "sun.max.fill", color: DaylineDesign.color("orange"), count: todayTasks.count, value: .today)
                    navRow("即将到来", symbol: "calendar", color: DaylineDesign.color("rose"), count: nil, value: .upcoming)
                    navRow("收件箱", symbol: "tray.fill", color: DaylineDesign.accent, count: inboxTasks.count, value: .inbox)
                    navRow("目标", symbol: "scope", color: DaylineDesign.color("purple"), count: nil, value: .goals)
                    navRow("灵感", symbol: "lightbulb", color: DaylineDesign.color("orange"), count: nil, value: .ideas)
                }
                Section("领域  ·  AREAS") {
                    ForEach(store.areas.sorted { $0.sortOrder < $1.sortOrder }, id: \.id) { area in
                        navRow(area.name, symbol: area.symbol, color: DaylineDesign.color(area.colorKey), count: nil, value: .area(area.id))
                    }
                }
            }.listStyle(.sidebar)
            VStack(alignment: .leading, spacing: 14) {
                Divider()
                HStack {
                    Text("每一天，都算数。").font(.system(size: 11)).foregroundStyle(.tertiary)
                    Spacer()
                    Menu {
                        Button("导出计划或灵感…", systemImage: "doc") { exportRequest = ExportRequest() }
                        Divider()
                        Button("导出备份…", systemImage: "square.and.arrow.up") { exportBackup() }
                        Button("从备份恢复…", systemImage: "square.and.arrow.down") { chooseBackup() }
                        Divider()
                        Button("添加示例内容…") { showDemoConfirmation = true }
                    } label: { Image(systemName: "ellipsis.circle").font(.system(size: 16)) }
                        .menuStyle(.borderlessButton).fixedSize().help("数据与备份")
                }
            }.padding(.horizontal, 20).padding(.bottom, 20)
        }
    }

    private func navRow(_ title: String, symbol: String, color: Color, count: Int?, value: DaylineDestination) -> some View {
        HStack(spacing: 11) {
            Image(systemName: symbol).font(.system(size: 15)).foregroundStyle(color).frame(width: 20)
            Text(title).font(.system(size: 13, weight: .medium))
            Spacer()
            if let count, count > 0 { Text("\(count)").font(.system(size: 11, design: .rounded)).foregroundStyle(.secondary) }
        }.padding(.vertical, 5).tag(value)
    }

    private var pageHeader: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(search.isEmpty ? "DAYLINE / \(englishLabel)" : "DAYLINE / SEARCH")
                .font(.system(size: 10, weight: .semibold)).tracking(2.2).foregroundStyle(.tertiary)
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(DaylineDesign.pageTitle)
                Spacer()
                if selection == .goals && search.isEmpty {
                    Button { goalEditor = GoalEditorRequest() } label: { Label("新建目标", systemImage: "plus") }.buttonStyle(.bordered)
                }
            }
            Text(subtitle).font(.system(size: 13)).foregroundStyle(.secondary)
        }.padding(.bottom, 26)
    }
    private var englishLabel: String {
        switch selection ?? .today { case .today: return "TODAY"; case .upcoming: return "UPCOMING"; case .inbox: return "INBOX"; case .goals: return "GOALS"; case .ideas: return "IDEAS"; case .area: return "AREAS" }
    }

    private var todayProgressTasks: [DayTask] {
        sortedTasks.filter { DaylineDates.isToday($0) || ($0.isCompleted && ($0.completedAt.map { Calendar.current.isDateInToday($0) } ?? false)) }
    }
    @ViewBuilder private var todayContent: some View {
        planningAdvice
        let progressTasks = todayProgressTasks
        if !progressTasks.isEmpty {
            HStack(spacing: 11) {
                ProgressView(value: Double(progressTasks.filter(\.isCompleted).count), total: Double(progressTasks.count))
                    .progressViewStyle(.linear).frame(width: 86).tint(DaylineDesign.accent.opacity(0.8))
                Text("已完成 \(progressTasks.filter(\.isCompleted).count) / \(progressTasks.count)")
                    .font(.system(size: 11, design: .rounded)).foregroundStyle(.secondary)
                Spacer()
            }.padding(.bottom, 15)
        }
        if !carriedTasks.isEmpty {
            SectionEyebrow(title: "待重新安排", count: carriedTasks.count, color: DaylineDesign.color("orange"), topSpacing: 8)
            Text("之前的计划还在这里。选择今天，或给它一个新的日期。")
                .font(.system(size: 12)).foregroundStyle(.secondary).padding(.bottom, 4)
            taskList(carriedTasks, carryover: true)
            Divider().padding(.top, 8).padding(.bottom, 6)
        }
        if todayTasks.isEmpty {
            QuietEmptyState(symbol: "sun.max", title: "为今天留下一件重要的事", detail: "安排一个小行动，让想做的事向前一步。", actionTitle: "添加今天的任务") { newTask() }
        } else {
            groupedTaskList(todayTasks)
        }
        quickCapture(scheduledDate: currentDate)
        completedSection(sortedTasks.filter { $0.isCompleted && (DaylineDates.isToday($0) || ($0.completedAt.map { Calendar.current.isDateInToday($0) } ?? false)) })
        DaylinePlanningSummary(report: PlanningAnalysis.analyze(events: store.planningEvents, asOf: currentDate))
    }

    @ViewBuilder private var planningAdvice: some View {
        let report = PlanningAnalysis.analyze(events: store.planningEvents, asOf: currentDate)
        let key = currentDate.formatted(.iso8601.year().month().day().dateSeparator(.dash))
        if report.coach.hasEnoughHistory && coachDismissedDay != key {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "leaf").foregroundStyle(DaylineDesign.color("green"))
                VStack(alignment: .leading, spacing: 5) {
                    Text(report.coach.title).font(.system(size: 12, weight: .medium))
                    Text(report.coach.message).font(.system(size: 12)).foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Button { coachDismissedDay = key } label: { Image(systemName: "xmark") }
                    .buttonStyle(.plain).help("今天不再显示建议")
            }.padding(14).background(DaylineDesign.accent.opacity(0.05), in: RoundedRectangle(cornerRadius: 9)).padding(.bottom, 18)
        }
    }

    @ViewBuilder private var inboxContent: some View {
        if inboxTasks.isEmpty {
            QuietEmptyState(symbol: "tray", title: "给脑海里的想法一个位置", detail: "任务只需要一个名字。日期、领域和目标，可以稍后再补。", actionTitle: "记下一件事") { newTask() }
        } else {
            taskList(inboxTasks)

        }
        quickCapture(scheduledDate: nil)
        completedSection(sortedTasks.filter { $0.isCompleted && DaylineDates.isInbox($0) })
    }

    private var nextDays: [Date] { (0..<7).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: Calendar.current.startOfDay(for: .now)) } }
    @ViewBuilder private var upcomingContent: some View {
        HStack(spacing: 7) {
            Button { selectedUpcomingDay = nil } label: {
                VStack(spacing: 6) { Text("查看").font(.system(size: 10)); Text("全部").font(.system(size: 15, weight: .medium)) }.frame(maxWidth: .infinity).padding(.vertical, 11)
            }.buttonStyle(.plain).background(selectedUpcomingDay == nil ? DaylineDesign.accent.opacity(0.1) : Color.clear, in: RoundedRectangle(cornerRadius: 10)).foregroundStyle(selectedUpcomingDay == nil ? DaylineDesign.accent : .secondary)
            ForEach(nextDays, id: \.self) { day in
                Button { selectedUpcomingDay = day } label: {
                    VStack(spacing: 6) {
                        Text(Calendar.current.isDateInToday(day) ? "今天" : day.formatted(.dateTime.weekday(.abbreviated))).font(.system(size: 10))
                        Text(day.formatted(.dateTime.day())).font(.system(size: 17, weight: .medium, design: .rounded))
                    }.frame(maxWidth: .infinity).padding(.vertical, 11)
                }.buttonStyle(.plain).background(selectedUpcomingDay == day ? DaylineDesign.accent.opacity(0.1) : Color.clear, in: RoundedRectangle(cornerRadius: 10)).foregroundStyle(selectedUpcomingDay == day ? DaylineDesign.accent : .secondary)
            }
        }.padding(.bottom, 14)
        if selectedUpcomingDay == nil {
            let overdue = openTasks.filter { DaylineDates.isOverdue($0) || DaylineDates.isUnfinishedPast($0) }
            if !overdue.isEmpty {
                SectionEyebrow(title: "逾期与未完成计划", count: overdue.count, color: DaylineDesign.color("orange"))
                taskList(overdue, carryover: true)
            }
        }
        ForEach(selectedUpcomingDay.map { [$0] } ?? nextDays, id: \.self) { day in
            let dayTasks = openTasks.filter { DaylineDates.occurs($0, on: day) }
            SectionEyebrow(title: day.formatted(.dateTime.month().day().weekday(.wide)), count: dayTasks.count)
            if dayTasks.isEmpty {
                Text("尚无安排").font(.system(size: 12)).foregroundStyle(.tertiary).padding(.vertical, 15)
            } else { taskList(dayTasks) }
            if selectedUpcomingDay != nil { addTaskRow("在这一天添加任务") { taskEditor = TaskEditorRequest(scheduledDate: day) } }
            Divider().padding(.top, 8)
        }
    }

    @ViewBuilder private var areaContent: some View {
        if let area = selectedArea {
            let goals = store.goals.filter { $0.areaID == area.id && $0.status == .active }
            let tasks = openTasks.filter { $0.areaID == area.id }
            if !goals.isEmpty {
                SectionEyebrow(title: "正在推进的目标", count: goals.count)
                ForEach(goals, id: \.id) { goal in goalRow(goal) }
                Divider().padding(.vertical, 14)
            }
            SectionEyebrow(title: "行动", count: tasks.count)
            if tasks.isEmpty {
                QuietEmptyState(symbol: area.symbol, title: "从一个小行动开始", detail: "为这个领域添加任务，也可以先写下你想实现的目标。", actionTitle: "添加行动") { newTask() }
            } else { taskList(tasks) }
            HStack {
                addTaskRow("添加行动") { newTask() }
                Button("新建目标") { goalEditor = GoalEditorRequest(areaID: area.id) }.buttonStyle(.plain).font(.system(size: 12)).foregroundStyle(.secondary)
            }
            completedSection(sortedTasks.filter { $0.areaID == area.id && $0.isCompleted })
        }
    }

    @ViewBuilder private var goalsContent: some View {
        let active = store.goals.filter { $0.status == .active }
        if store.goals.isEmpty {
            QuietEmptyState(symbol: "scope", title: "你希望走向哪里？", detail: "用长期目标写下方向，再拆成短期成果。关联任务，让每一步都有意义。", actionTitle: "写下第一个目标") { goalEditor = GoalEditorRequest() }
        } else {
            let longGoals = active.filter { $0.kind == .longTerm }
            let standalone = active.filter { goal in goal.kind == .shortTerm && (goal.parentGoalID == nil || !active.contains(where: { parent in parent.id == goal.parentGoalID && parent.kind == .longTerm })) }
            if !longGoals.isEmpty {
                SectionEyebrow(title: "长期方向", count: longGoals.count)
                ForEach(longGoals, id: \.id) { goal in
                    goalRow(goal)
                    let children = active.filter { $0.parentGoalID == goal.id && $0.kind == .shortTerm }
                    ForEach(children, id: \.id) { child in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "arrow.turn.down.right").font(.system(size: 12)).foregroundStyle(.tertiary).padding(.top, 20)
                            goalRow(child)
                        }.padding(.leading, 18)
                    }
                    Button { goalEditor = GoalEditorRequest(areaID: goal.areaID, parentGoalID: goal.id) } label: { Label("添加短期目标", systemImage: "plus") }
                        .buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(.secondary).padding(.leading, 44).padding(.bottom, 18)
                }
            }
            if !standalone.isEmpty {
                SectionEyebrow(title: "短期成果", count: standalone.count)
                ForEach(standalone, id: \.id) { goal in goalRow(goal) }
            }
            let finished = store.goals.filter { $0.status != .active }
            if !finished.isEmpty {
                DisclosureGroup("已完成与归档 · \(finished.count)") {
                    ForEach(finished, id: \.id) { goal in goalRow(goal) }
                }.font(.system(size: 12)).foregroundStyle(.secondary).padding(.top, 25)
            }
        }
    }

    @ViewBuilder private var searchContent: some View {
        if matchingTasks.isEmpty && matchingGoals.isEmpty {
            QuietEmptyState(symbol: "magnifyingglass", title: "没有找到相关内容", detail: "换一个关键词试试。搜索包含任务、目标及其备注。")
        } else {
            if !matchingTasks.isEmpty {
                SectionEyebrow(title: "任务", count: matchingTasks.count)
                taskList(matchingTasks)
            }
            if !matchingGoals.isEmpty {
                SectionEyebrow(title: "目标", count: matchingGoals.count)
                ForEach(matchingGoals, id: \.id) { goal in goalRow(goal) }
            }
        }
    }

    @ViewBuilder private func groupedTaskList(_ tasks: [DayTask]) -> some View {
        ForEach(store.areas.sorted { $0.sortOrder < $1.sortOrder }, id: \.id) { area in
            let inArea = tasks.filter { $0.areaID == area.id }
            if !inArea.isEmpty {
                SectionEyebrow(title: area.name, count: inArea.count, color: DaylineDesign.color(area.colorKey))
                taskList(inArea)
            }
        }
        let unassigned = tasks.filter { task in task.areaID == nil || !store.areas.contains(where: { $0.id == task.areaID }) }
        if !unassigned.isEmpty {
            SectionEyebrow(title: "其他行动", count: unassigned.count)
            taskList(unassigned)
        }
    }

    private func taskList(_ tasks: [DayTask], carryover: Bool = false) -> some View {
        LazyVStack(spacing: 0) {
            ForEach(tasks, id: \.id) { task in
                DaylineTaskRow(task: task, area: store.areas.first { $0.id == task.areaID }, goal: store.goals.first { $0.id == task.goalID }, carryover: carryover, onToggle: { toggle(task) }, onEdit: { taskEditor = TaskEditorRequest(task: task) }, onToday: { store.reschedule(task, to: .now) })
                    .contextMenu {
                        Button("编辑任务…") { taskEditor = TaskEditorRequest(task: task) }
                        Button(task.isCompleted ? "标记为未完成" : "完成任务") { toggle(task) }
                        Divider()
                        Button("安排到今天") { store.reschedule(task, to: .now) }
                        Button("安排到明天") { store.reschedule(task, to: Calendar.current.date(byAdding: .day, value: 1, to: .now)) }
                        Button("移除计划日期") { store.reschedule(task, to: nil) }
                        Divider()
                        Button("删除任务…", role: .destructive) { deleteTaskID = task.id }
                    }
                    .draggable(task.id.uuidString)
                    .dropDestination(for: String.self) { values, location in
                        guard let value = values.first, let id = UUID(uuidString: value), id != task.id else { return false }
                        var ids = sortedTasks.map(\.id)
                        guard let source = ids.firstIndex(of: id) else { return false }
                        ids.remove(at: source)
                        guard let target = ids.firstIndex(of: task.id) else { return false }
                        ids.insert(id, at: min(target + (location.y > 25 ? 1 : 0), ids.count))
                        store.reorderTasks(ids)
                        return true
                    }
                Rectangle().fill(DaylineDesign.line).frame(height: 1).padding(.leading, 34)
            }
        }
    }

    @ViewBuilder private func completedSection(_ tasks: [DayTask]) -> some View {
        if !tasks.isEmpty {
            DisclosureGroup(isExpanded: $completedExpanded) { taskList(tasks) } label: {
                Text("已完成 · \(tasks.count)").font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
            }.padding(.top, 28)
        }
    }

    private func goalRow(_ goal: Goal) -> some View {
        let actions = store.tasks.filter { $0.goalID == goal.id }
        let done = actions.filter(\.isCompleted).count
        let area = store.areas.first { $0.id == goal.areaID }
        return VStack(alignment: .leading, spacing: 0) {
        Button { goalEditor = GoalEditorRequest(goal: goal) } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 11) {
                    Image(systemName: goal.status == .completed ? "checkmark.circle.fill" : (goal.kind == .longTerm ? "scope" : "flag"))
                        .font(.system(size: 17)).foregroundStyle(DaylineDesign.color(area?.colorKey)).frame(width: 23)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(goal.title).font(.system(size: 14, weight: .medium)).foregroundStyle(.primary)
                        if !goal.notes.isEmpty { Text(goal.notes).font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(2) }
                    }
                    Spacer(minLength: 15)
                    if goal.status != .active { Text(goal.status == .completed ? "已完成" : "已归档").font(.system(size: 10)).foregroundStyle(.secondary) }
                    else if let date = goal.targetDate { Text(date.formatted(.dateTime.month().day())).font(.system(size: 11)).foregroundStyle(.secondary) }
                }
                HStack(spacing: 16) {
                    HStack(spacing: 8) {
                        ProgressView(value: min(max(goal.progress, 0), 1)).progressViewStyle(.linear).frame(width: 100).tint(DaylineDesign.color(area?.colorKey))
                        Text("成果 \(Int(goal.progress * 100))%").font(.system(size: 10, design: .rounded))
                    }
                    Text("行动 \(done)/\(actions.count)").font(.system(size: 10, design: .rounded))
                    if let area { Text(area.name).font(.system(size: 10)) }
                    Spacer()
                }.foregroundStyle(.secondary).padding(.leading, 34)
            }.padding(.vertical, 14).contentShape(Rectangle())
        }.buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(goal.title)，成果进度 \(Int(goal.progress * 100))%，关联行动已完成 \(done) / \(actions.count)")
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("编辑目标")
            .contextMenu {
                Button("编辑目标…") { goalEditor = GoalEditorRequest(goal: goal) }
                Button("添加关联任务…") { taskEditor = TaskEditorRequest(areaID: goal.areaID, goalID: goal.id) }
                if goal.kind == .longTerm { Button("添加短期目标…") { goalEditor = GoalEditorRequest(areaID: goal.areaID, parentGoalID: goal.id) } }
                Divider()
                Button(goal.status == .completed ? "重新启用" : "标记为已完成") { store.setGoalStatus(goal, to: goal.status == .completed ? .active : .completed) }
                Button(goal.status == .archived ? "取消归档" : "归档目标") { store.setGoalStatus(goal, to: goal.status == .archived ? .active : .archived) }
                Divider()
                Button("删除目标…", role: .destructive) { deleteGoalID = goal.id }
            }
        if !actions.isEmpty {
            DisclosureGroup {
                taskList(actions)
            } label: {
                Text("查看关联行动 · \(actions.count)").font(.system(size: 11)).foregroundStyle(.secondary)
            }.padding(.leading, 34).padding(.bottom, 13)
        }
        }
    }

    private func quickCapture(scheduledDate: Date?) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "plus").font(.system(size: 16, weight: .light)).foregroundStyle(.tertiary).frame(width: 22)
            TextField("添加任务，按回车保存…", text: $quickTitle)
                .textFieldStyle(.plain).font(.system(size: 13))
                .accessibilityIdentifier("quickTaskField")
                .onSubmit {
                    if store.addTask(title: quickTitle, scheduledDate: scheduledDate) != nil { quickTitle = "" }
                }
            if !quickTitle.isEmpty {
                Button {
                    if store.addTask(title: quickTitle, scheduledDate: scheduledDate) != nil { quickTitle = "" }
                } label: { Image(systemName: "return") }.buttonStyle(.plain).foregroundStyle(.secondary).help("添加任务")
            }
        }.padding(.vertical, 17).padding(.horizontal, 5)
    }

    private func addTaskRow(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(label, systemImage: "plus").font(.system(size: 13)).foregroundStyle(.secondary).padding(.vertical, 17)
        }.buttonStyle(.plain)
    }
    private func newTask() {
        guard taskEditor == nil && goalEditor == nil else { return }
        var date: Date?
        if selection == .today { date = .now }
        if selection == .upcoming { date = selectedUpcomingDay ?? .now }
        taskEditor = TaskEditorRequest(areaID: selectedArea?.id, scheduledDate: date)
    }

    private func openQADatePreviewIfRequested() {
        let process = ProcessInfo.processInfo
        guard process.arguments.contains("--qa-store") else { return }
        if process.environment["DAYLINE_OPEN_GOAL_DATE"] == "1", goalEditor == nil,
           let goal = store.goals.first(where: { $0.targetDate != nil }) ?? store.goals.first {
            selection = .goals
            goalEditor = GoalEditorRequest(goal: goal)
        }
        if process.environment["DAYLINE_OPEN_TASK_DATE"] == "1", taskEditor == nil,
           let task = store.tasks.first(where: { $0.scheduledDate != nil }) ?? store.tasks.first {
            selection = .today
            taskEditor = TaskEditorRequest(task: task)
        }
    }
    private func toggle(_ task: DayTask) {
        let willComplete = !task.isCompleted
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) { store.toggleTask(task) }
        guard store.errorMessage == nil else { return }
        if willComplete { toast = "已完成“\(task.title)”"; undoTaskID = task.id }
        else { toast = "已恢复任务"; undoTaskID = nil }
    }
    private func undoCompletion() {
        if let task = store.tasks.first(where: { $0.id == undoTaskID }), task.isCompleted { store.toggleTask(task) }
        toast = nil; undoTaskID = nil
    }
    private func exportBackup() {
        let panel = NSSavePanel()
        panel.title = "导出 Dayline 备份"
        panel.nameFieldStringValue = "Dayline-\(Date.now.formatted(.iso8601.year().month().day().dateSeparator(.dash))).json"
        panel.allowedContentTypes = [.json]
        presentPanel(panel) { response in
            guard response == .OK, let url = panel.url else { return }
            do { try store.exportBackup().write(to: url, options: .atomic); toast = "备份已导出"; undoTaskID = nil }
            catch { localError = error.localizedDescription }
        }
    }
    private func chooseBackup() {
        let panel = NSOpenPanel()
        panel.title = "选择 Dayline 备份"
        panel.allowedContentTypes = [.json]
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        presentPanel(panel) { response in
            guard response == .OK, let url = panel.url else { return }
            do { pendingBackup = try Data(contentsOf: url); backupName = url.lastPathComponent; showRestoreConfirmation = true }
            catch { localError = error.localizedDescription }
        }
    }
    private func presentPanel(_ panel: NSSavePanel, completion: @escaping (NSApplication.ModalResponse) -> Void) {
        // Attach to the document window and avoid a nested application event loop.
        if let window = NSApp.keyWindow ?? NSApp.windows.first(where: { $0.canBecomeMain }) {
            panel.beginSheetModal(for: window, completionHandler: completion)
        } else {
            panel.begin(completionHandler: completion)
        }
    }
    private func restoreBackup() {
        guard let data = pendingBackup else { return }
        do { try store.restoreBackup(data); toast = "已恢复备份"; undoTaskID = nil; selection = .today }
        catch { localError = error.localizedDescription }
        pendingBackup = nil
    }
}
