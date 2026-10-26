import SwiftUI
import DaylineCore
import DaylineData

struct TodayView: View {
    @Environment(DaylineStore.self) private var store
    @State private var draft = ""
    @State private var editor: PhoneTaskRequest?
    @State private var showCompleted = false
    @State private var pendingDelete: DayTask?

    private var open: [DayTask] { PhoneTasks.open(store) }
    private var overdue: [DayTask] { open.filter { (DaylineDates.isOverdue($0) || DaylineDates.isUnfinishedPast($0)) && !DaylineDates.isToday($0) } }
    private var today: [DayTask] { open.filter { DaylineDates.isToday($0) } }
    private var completed: [DayTask] {
        PhoneTasks.sorted(store.tasks.filter { task in
            task.isCompleted && (DaylineDates.isToday(task) || (task.completedAt.map { Calendar.current.isDateInToday($0) } ?? false))
        })
    }

    var body: some View {
        NavigationStack {
            Group {
                if overdue.isEmpty && today.isEmpty && completed.isEmpty {
                    PhoneEmpty(symbol: "sun.max", title: "今天还没有安排", detail: "把一件想做的事记在下方。完成之后，它会安静地收起来。")
                } else {
                    List {
                        taskSection("逾期", tasks: overdue)
                        taskSection("今天", tasks: today)
                        if !completed.isEmpty {
                            Section {
                                if showCompleted {
                                    ForEach(completed, id: \.id) { task in
                                        PhoneTaskRow(task: task) { editor = PhoneTaskRequest(task: task) }
                                            .swipeActions { deleteSwipe(task) }
                                    }
                                }
                            } header: {
                                Button { withAnimation(.snappy) { showCompleted.toggle() } } label: {
                                    HStack {
                                        Text("已完成 \(completed.count)")
                                        Spacer()
                                        Image(systemName: showCompleted ? "chevron.down" : "chevron.right")
                                    }
                                    .font(.subheadline.weight(.semibold))
                                    .textCase(nil)
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("今天")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { editor = PhoneTaskRequest(scheduledDate: Calendar.current.startOfDay(for: Date())) } label: {
                        Image(systemName: "square.and.pencil")
                    }
                    .accessibilityLabel("新建任务")
                }
            }
            .safeAreaInset(edge: .bottom) {
                QuickCaptureBar(placeholder: "添加今天的任务", identifier: "quick-add-today", text: $draft) { addDraft() }
            }
            .scrollDismissesKeyboard(.interactively)
            .sheet(item: $editor) { PhoneTaskEditor(request: $0) }
            .confirmationDialog("删除这项任务？", isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }), titleVisibility: .visible) {
                Button("删除任务", role: .destructive) { if let pendingDelete { store.deleteTask(pendingDelete) } }
                Button("取消", role: .cancel) { pendingDelete = nil }
            }
            .accessibilityIdentifier("screen-today")
        }
    }

    @ViewBuilder private func taskSection(_ title: String, tasks: [DayTask]) -> some View {
        if !tasks.isEmpty {
            Section(title) {
                ForEach(tasks, id: \.id) { task in
                    PhoneTaskRow(task: task) { editor = PhoneTaskRequest(task: task) }
                        .swipeActions { deleteSwipe(task) }
                }
            }
        }
    }

    private func deleteSwipe(_ task: DayTask) -> some View {
        Button(role: .destructive) { pendingDelete = task } label: { Label("删除", systemImage: "trash") }
    }

    private func addDraft() {
        let title = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        if store.addTask(title: title, scheduledDate: Calendar.current.startOfDay(for: Date())) != nil { draft = "" }
    }
}

struct UpcomingView: View {
    @Environment(DaylineStore.self) private var store
    @State private var selected = Calendar.current.startOfDay(for: Date())
    @State private var editor: PhoneTaskRequest?
    @State private var pendingDelete: DayTask?

    private var days: [Date] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        return (0..<14).compactMap { DaylineDateSelection.byAddingDays($0, to: start, calendar: calendar) }
    }
    private var tasks: [DayTask] { PhoneTasks.open(store).filter { DaylineDates.occurs($0, on: selected) } }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(days, id: \.timeIntervalSinceReferenceDate) { day in
                            dayButton(day)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .accessibilityIdentifier("upcoming-days")
                if tasks.isEmpty {
                    PhoneEmpty(symbol: "calendar", title: "这一天是空的", detail: "选一个日期，把任务放到它该发生的时候。")
                } else {
                    List {
                        Section(selected.formatted(.dateTime.month(.wide).day().weekday(.wide))) {
                            ForEach(tasks, id: \.id) { task in
                                PhoneTaskRow(task: task) { editor = PhoneTaskRequest(task: task) }
                                    .swipeActions {
                                        Button(role: .destructive) { pendingDelete = task } label: { Label("删除", systemImage: "trash") }
                                    }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("即将到来")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { editor = PhoneTaskRequest(scheduledDate: selected) } label: { Image(systemName: "plus") }
                        .accessibilityLabel("在这一天新建任务")
                }
            }
            .sheet(item: $editor) { PhoneTaskEditor(request: $0) }
            .confirmationDialog("删除这项任务？", isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }), titleVisibility: .visible) {
                Button("删除任务", role: .destructive) { if let pendingDelete { store.deleteTask(pendingDelete) } }
                Button("取消", role: .cancel) {}
            }
            .accessibilityIdentifier("screen-upcoming")
        }
    }

    private func dayButton(_ day: Date) -> some View {
        let selectedDay = Calendar.current.isDate(day, inSameDayAs: selected)
        let count = PhoneTasks.open(store).filter { DaylineDates.occurs($0, on: day) }.count
        return Button { selected = day } label: {
            VStack(spacing: 4) {
                Text(day.formatted(.dateTime.weekday(.narrow))).font(.caption)
                Text(day.formatted(.dateTime.day())).font(.body.weight(.semibold))
                Circle().fill(count > 0 ? PhoneDesign.accent : Color.clear).frame(width: 5, height: 5)
            }
            .frame(width: 52, height: 72)
            .foregroundStyle(selectedDay ? Color.white : Color.primary)
            .background(selectedDay ? PhoneDesign.accent : Color(.secondarySystemFill), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(day.formatted(.dateTime.month().day().weekday(.wide)))
        .accessibilityAddTraits(selectedDay ? .isSelected : [])
    }
}

struct InboxView: View {
    @Environment(DaylineStore.self) private var store
    @State private var draft = ""
    @State private var editor: PhoneTaskRequest?
    @State private var pendingDelete: DayTask?

    private var tasks: [DayTask] { PhoneTasks.open(store).filter { DaylineDates.isInbox($0) } }

    var body: some View {
        NavigationStack {
            Group {
                if tasks.isEmpty {
                    PhoneEmpty(symbol: "tray", title: "收件箱是空的", detail: "先记下来。稍后再决定领域、目标和日期。")
                } else {
                    List {
                        Section("待整理") {
                            ForEach(tasks, id: \.id) { task in
                                PhoneTaskRow(task: task) { editor = PhoneTaskRequest(task: task) }
                                    .swipeActions {
                                        Button(role: .destructive) { pendingDelete = task } label: { Label("删除", systemImage: "trash") }
                                    }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("收件箱")
            .navigationBarTitleDisplayMode(.large)
            .safeAreaInset(edge: .bottom) {
                QuickCaptureBar(placeholder: "快速记下一件事", identifier: "quick-add-inbox", text: $draft) { addDraft() }
            }
            .scrollDismissesKeyboard(.interactively)
            .sheet(item: $editor) { PhoneTaskEditor(request: $0) }
            .confirmationDialog("删除这项任务？", isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }), titleVisibility: .visible) {
                Button("删除任务", role: .destructive) { if let pendingDelete { store.deleteTask(pendingDelete) } }
                Button("取消", role: .cancel) {}
            }
            .accessibilityIdentifier("screen-inbox")
        }
    }

    private func addDraft() {
        let title = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        if store.addTask(title: title) != nil { draft = "" }
    }
}

struct PhoneRootView: View {
    @Environment(DaylineStore.self) private var store
    @State private var tab: PhoneTab

    init(initialTab: PhoneTab) { _tab = State(initialValue: initialTab) }

    private var inboxCount: Int { PhoneTasks.open(store).filter { DaylineDates.isInbox($0) }.count }

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch tab {
                case .today: TodayView()
                case .upcoming: UpcomingView()
                case .inbox: InboxView()
                case .goals: GoalsView()
                case .ideas: IdeasView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            PhoneTabBar(tab: $tab, inboxCount: inboxCount)
        }
        .tint(PhoneDesign.accent)
        .alert("无法保存", isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })) {
            Button("好") { store.errorMessage = nil }
        } message: {
            Text(store.errorMessage ?? "")
        }
    }
}

private struct PhoneTabBar: View {
    @Binding var tab: PhoneTab
    var inboxCount: Int

    var body: some View {
        HStack(spacing: 0) {
            item(.today, "今天", "sun.max")
            item(.upcoming, "即将到来", "calendar")
            item(.inbox, "收件箱", "tray", badge: inboxCount)
            item(.goals, "目标", "scope")
            item(.ideas, "灵感", "lightbulb")
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(.bar, ignoresSafeAreaEdges: .bottom)
        .overlay(alignment: .top) { Divider().opacity(0.6) }
    }

    private func item(_ value: PhoneTab, _ title: String, _ symbol: String, badge: Int = 0) -> some View {
        Button { tab = value } label: {
            VStack(spacing: 3) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: symbol)
                        .font(.system(size: 20, weight: tab == value ? .semibold : .regular))
                        .frame(height: 24)
                    if badge > 0 {
                        Text("\(badge)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4)
                            .background(Capsule().fill(Color.red))
                            .offset(x: 12, y: -6)
                    }
                }
                Text(title).font(.system(size: 10, weight: tab == value ? .semibold : .regular))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .foregroundStyle(tab == value ? PhoneDesign.accent : Color.secondary)
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityIdentifier("tab-\(value.rawValue)")
        .accessibilityAddTraits(tab == value ? .isSelected : [])
    }
}
