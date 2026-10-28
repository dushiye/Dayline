import SwiftUI
import Observation
import DaylineCore
import DaylineData

@MainActor @Observable
final class DailyReviewDraftSession {
    var selectedDayKey: String
    var loadedDayKey: String?
    var timeZoneID: String
    var learned = ""
    var growth = ""
    var nextStep = ""
    var freeformNotes = ""
    var isDirty = false
    var lastSavedAt: Date?

    init(now: Date = Date(), timeZone: TimeZone = .current) {
        selectedDayKey = DailyReviewDay.key(for: now, timeZone: timeZone)
        timeZoneID = timeZone.identifier
    }

    var hasContent: Bool {
        [learned, growth, nextStep, freeformNotes].contains {
            !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    func request(_ dayKey: String) {
        guard !isDirty else { return }
        selectedDayKey = dayKey
        loadedDayKey = nil
    }

    func load(dayKey: String, from store: DaylineStore, timeZone: TimeZone = .current) {
        if loadedDayKey == dayKey { return }
        let review = store.dailyReview(for: dayKey)
        selectedDayKey = dayKey
        loadedDayKey = dayKey
        timeZoneID = review?.timeZoneID ?? timeZone.identifier
        learned = review?.learned ?? ""
        growth = review?.growth ?? ""
        nextStep = review?.nextStep ?? ""
        freeformNotes = review?.freeformNotes ?? ""
        isDirty = false
        lastSavedAt = review?.updatedAt
    }

    func clear(dayKey: String, timeZone: TimeZone = .current) {
        selectedDayKey = dayKey
        loadedDayKey = dayKey
        timeZoneID = timeZone.identifier
        learned = ""; growth = ""; nextStep = ""; freeformNotes = ""
        isDirty = false; lastSavedAt = nil
    }

    /// The view debounces calls to this method. A failed commit deliberately leaves the
    /// draft dirty and in memory so navigation cannot silently discard the user's text.
    @discardableResult
    func persist(to store: DaylineStore) -> Bool {
        guard isDirty else { return store.errorMessage == nil }
        _ = store.updateDailyReview(dayKey: selectedDayKey, timeZoneID: timeZoneID,
                                    learned: learned, growth: growth,
                                    nextStep: nextStep, freeformNotes: freeformNotes)
        guard store.errorMessage == nil else { return false }
        isDirty = false
        lastSavedAt = store.dailyReview(for: selectedDayKey)?.updatedAt
        return true
    }
}

struct DaylineDailyReviewView: View {
    @Environment(DaylineStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @Bindable var session: DailyReviewDraftSession
    let onExport: (String) -> Void

    @State private var saveTask: Task<Void, Never>?
    @State private var showDeleteConfirmation = false
    @State private var checkpointNeeded = false

    private var selectedDate: Date {
        DailyReviewDay.date(for: session.selectedDayKey, timeZone: .current) ?? Date()
    }
    private var todayKey: String { DailyReviewDay.key(for: Date(), timeZone: .current) }
    private var savedReview: DailyReview? { store.dailyReview(for: session.selectedDayKey) }
    private var daySummary: PlanningDaySummary? {
        let report = PlanningAnalysis.analyze(events: store.planningEvents, asOf: Date(), timeZone: .current)
        return report.days.first { $0.dayKey == session.selectedDayKey }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if let daySummary { planningSummary(daySummary) }
                    promptEditor(
                        title: "今天学到了什么？",
                        symbol: "text.book.closed",
                        placeholder: "试着讲清楚一个今天学到的新概念、新方法或新认识。",
                        text: binding(\.learned),
                        identifier: "reviewLearnedEditor"
                    )
                    Divider().padding(.vertical, 8)
                    promptEditor(
                        title: "今天有哪些成长或进展？",
                        symbol: "leaf",
                        placeholder: "记录一个值得肯定的进步，即使它很小。",
                        text: binding(\.growth),
                        identifier: "reviewGrowthEditor"
                    )
                    Divider().padding(.vertical, 8)
                    promptEditor(
                        title: "明天想继续或改进什么？",
                        symbol: "arrow.forward",
                        placeholder: "想一想明天要继续做什么，或者调整哪一种方法。",
                        text: binding(\.nextStep),
                        identifier: "reviewNextStepEditor"
                    )
                    Divider().padding(.vertical, 8)
                    promptEditor(
                        title: "自由记录",
                        symbol: "square.and.pencil",
                        placeholder: "写下其他想保留的片段、感受或问题。",
                        text: binding(\.freeformNotes),
                        identifier: "reviewFreeformEditor",
                        compact: true
                    )
                    footer
                }
                .frame(maxWidth: 720, alignment: .leading)
                .padding(.horizontal, 46)
                .padding(.top, 28)
                .padding(.bottom, 44)
                .frame(maxWidth: .infinity)
            }
        }
        .background(DaylineDesign.canvas)
        .onAppear {
            session.load(dayKey: session.selectedDayKey, from: store)
        }
        .onDisappear { flush(checkpoint: true) }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { flush(checkpoint: true) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .daylineWillTerminate)) { _ in
            flush(checkpoint: true)
        }
        .confirmationDialog("删除这一天的回顾？", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("删除回顾", role: .destructive, action: deleteReview)
            Button("取消", role: .cancel) { }
        } message: {
            Text("删除后无法撤销。当天的任务和计划历史不会受到影响。")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("DAYLINE / DAILY REVIEW")
                        .font(.system(size: 10, weight: .semibold)).tracking(2.2).foregroundStyle(.tertiary)
                    Text("每日回顾").font(DaylineDesign.pageTitle)
                    Text("把今天学到的，变成真正属于自己的东西。")
                        .font(.system(size: 13)).foregroundStyle(.secondary)
                }
                Spacer()
                Menu {
                    if store.dailyReviews.isEmpty {
                        Text("还没有历史回顾")
                    } else {
                        ForEach(store.dailyReviews, id: \.id) { review in
                            Button(historyLabel(review.dayKey)) { select(dayKey: review.dayKey) }
                        }
                    }
                } label: {
                    Label("历史", systemImage: "clock.arrow.circlepath")
                }
                .help("查看写过回顾的日期")
                Button { exportReview() } label: {
                    Label("导出", systemImage: "square.and.arrow.up")
                }
                .disabled(savedReview == nil && !session.hasContent)
                .help("导出每日回顾")
                if savedReview != nil || session.hasContent {
                    Button(role: .destructive) { showDeleteConfirmation = true } label: {
                        Image(systemName: "trash")
                    }.help("删除这一天的回顾")
                }
            }
            HStack(spacing: 10) {
                Button { move(by: -1) } label: { Image(systemName: "chevron.left") }
                    .help("前一天").accessibilityLabel("前一天")
                DaylineDateField(date: Binding(get: { selectedDate }, set: { date in
                    select(dayKey: DailyReviewDay.key(for: date, timeZone: .current))
                }), label: "回顾日期", identifier: "dailyReviewDate", allowsClear: false)
                Button { move(by: 1) } label: { Image(systemName: "chevron.right") }
                    .help("后一天").accessibilityLabel("后一天")
                if session.selectedDayKey != todayKey {
                    Button("今天") { select(dayKey: todayKey) }.buttonStyle(.borderless)
                }
                Spacer()
                Circle()
                    .fill(savedReview == nil ? Color.secondary.opacity(0.22) : DaylineDesign.accent.opacity(0.75))
                    .frame(width: 6, height: 6)
                Text(savedReview == nil ? "这一天还没有回顾" : "这一天已经写过回顾")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 34).padding(.top, 30).padding(.bottom, 22)
    }

    private func planningSummary(_ day: PlanningDaySummary) -> some View {
        HStack(spacing: 11) {
            Image(systemName: "checklist").foregroundStyle(.secondary)
            Text("当日计划 \(day.planned) 项")
            Text("·").foregroundStyle(.tertiary)
            Text("实际完成 \(day.actualCompleted) 项")
            if day.activelyRescheduled > 0 {
                Text("·").foregroundStyle(.tertiary)
                Text("主动改期 \(day.activelyRescheduled) 项")
            }
            Spacer()
        }
        .font(.system(size: 11)).foregroundStyle(.secondary)
        .padding(.bottom, 22)
        .accessibilityElement(children: .combine)
    }

    private func promptEditor(title: String, symbol: String, placeholder: String, text: Binding<String>,
                              identifier: String, compact: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            Label(title, systemImage: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary)
            ZStack(alignment: .topLeading) {
                TextEditor(text: text)
                    .font(.system(size: 14)).lineSpacing(6)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: compact ? 90 : 128)
                    .accessibilityLabel(title)
                    .accessibilityIdentifier(identifier)
                if text.wrappedValue.isEmpty {
                    Text(placeholder)
                        .font(.system(size: 14)).foregroundStyle(.tertiary).lineSpacing(6)
                        .padding(.top, 1).padding(.leading, 5).allowsHitTesting(false)
                }
            }
        }
        .padding(.vertical, 18)
    }

    private var footer: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: store.errorMessage == nil ? (session.isDirty ? "ellipsis.circle" : "checkmark.circle") : "exclamationmark.circle")
                .foregroundStyle(store.errorMessage == nil ? Color.secondary : Color.red)
            VStack(alignment: .leading, spacing: 3) {
                Text(saveStatus)
                if let error = store.errorMessage {
                    Text(error).foregroundStyle(.red).textSelection(.enabled)
                }
            }
            Spacer()
            if store.errorMessage != nil {
                Button("重试保存") { _ = saveNow() }.buttonStyle(.borderless)
            }
        }
        .font(.system(size: 11)).foregroundStyle(.secondary)
        .padding(.top, 18)
    }

    private var saveStatus: String {
        if store.errorMessage != nil { return "保存失败，文字仍保留在当前编辑草稿中。" }
        if session.isDirty { return "正在等待自动保存…" }
        if let date = session.lastSavedAt { return "已自动保存 · \(date.formatted(.dateTime.hour().minute()))" }
        return "填写任意一项后自动保存。"
    }

    private func binding(_ keyPath: ReferenceWritableKeyPath<DailyReviewDraftSession, String>) -> Binding<String> {
        let draft = session
        return Binding(get: { draft[keyPath: keyPath] }, set: { value in
            draft[keyPath: keyPath] = value
            draft.isDirty = true
            scheduleSave()
        })
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(700))
            guard !Task.isCancelled else { return }
            _ = saveNow()
        }
    }

    @discardableResult private func saveNow() -> Bool {
        saveTask?.cancel(); saveTask = nil
        let wasDirty = session.isDirty
        guard session.persist(to: store) else { return false }
        guard wasDirty else { return true }
        checkpointNeeded = true
        return true
    }

    private func flush(checkpoint: Bool) {
        let saved = saveNow()
        if checkpoint && saved && checkpointNeeded {
            store.runReviewCheckpointBackup()
            if store.errorMessage == nil { checkpointNeeded = false }
        }
    }

    private func select(dayKey: String) {
        guard dayKey != session.selectedDayKey else { return }
        guard saveNow() else { return }
        if checkpointNeeded { store.runReviewCheckpointBackup(); checkpointNeeded = store.errorMessage != nil }
        session.load(dayKey: dayKey, from: store)
    }

    private func move(by days: Int) {
        guard let key = DailyReviewDay.addingDays(days, to: session.selectedDayKey) else { return }
        select(dayKey: key)
    }

    private func deleteReview() {
        saveTask?.cancel(); saveTask = nil
        if let review = savedReview { store.deleteDailyReview(review) }
        guard store.errorMessage == nil else { return }
        session.clear(dayKey: session.selectedDayKey)
        checkpointNeeded = true
        store.runReviewCheckpointBackup()
        checkpointNeeded = store.errorMessage != nil
    }

    private func exportReview() {
        guard saveNow() else { return }
        onExport(session.selectedDayKey)
    }

    private func historyLabel(_ key: String) -> String {
        guard let date = DailyReviewDay.date(for: key, timeZone: .current) else { return key }
        return date.formatted(.dateTime.year().month().day().weekday(.wide))
    }
}
