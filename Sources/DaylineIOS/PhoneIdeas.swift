import SwiftUI
import DaylineData

private enum IdeaFilter: String, CaseIterable, Identifiable {
    case active = "进行中"
    case pinned = "置顶"
    case archived = "归档"
    var id: String { rawValue }
}

struct IdeasView: View {
    @Environment(DaylineStore.self) private var store
    @State private var filter = IdeaFilter.active
    @State private var draft = ""
    @State private var path: [UUID] = []

    private var ideas: [Idea] {
        let query = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        return store.ideas.filter { idea in
            let status: Bool
            switch filter {
            case .active: status = !idea.isArchived
            case .pinned: status = idea.isPinned && !idea.isArchived
            case .archived: status = idea.isArchived
            }
            let matches = query.isEmpty || idea.title.localizedStandardContains(query) || idea.body.localizedStandardContains(query)
            return status && matches
        }.sorted {
            if $0.isPinned != $1.isPinned { return $0.isPinned && !$1.isPinned }
            if $0.updatedAt != $1.updatedAt { return $0.updatedAt > $1.updatedAt }
            return $0.id.uuidString < $1.id.uuidString
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if ideas.isEmpty {
                    PhoneEmpty(symbol: "lightbulb", title: "给想法留一点空间", detail: "写下一句就好。它会自动保存，也可以以后变成任务。")
                } else {
                    List {
                        ForEach(ideas, id: \.id) { idea in
                            NavigationLink(value: idea.id) {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        if idea.isPinned { Image(systemName: "pin.fill").font(.caption).foregroundStyle(PhoneDesign.accent) }
                                        Text(idea.title.isEmpty ? "未命名灵感" : idea.title)
                                            .font(.body.weight(.medium))
                                            .lineLimit(1)
                                    }
                                    if !idea.body.isEmpty {
                                        Text(idea.body).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                            .swipeActions {
                                Button { store.setIdeaPinned(idea, to: !idea.isPinned) } label: {
                                    Label(idea.isPinned ? "取消置顶" : "置顶", systemImage: "pin")
                                }
                                .tint(PhoneDesign.accent)
                                Button { store.setIdeaArchived(idea, to: !idea.isArchived) } label: {
                                    Label(idea.isArchived ? "取消归档" : "归档", systemImage: "archivebox")
                                }
                                .tint(.orange)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("灵感")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: UUID.self) { id in
                if let idea = store.ideas.first(where: { $0.id == id }) {
                    IdeaDetail(idea: idea)
                } else {
                    PhoneEmpty(symbol: "lightbulb", title: "这条灵感已经不在了", detail: "")
                }
            }
            .searchable(text: $draft, prompt: "搜索灵感")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Picker("筛选", selection: $filter) {
                        ForEach(IdeaFilter.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.menu)
                    .accessibilityIdentifier("idea-filter")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: add) { Image(systemName: "square.and.pencil") }
                        .accessibilityLabel("新灵感")
                        .accessibilityIdentifier("idea-add")
                }
            }
            .accessibilityIdentifier("screen-ideas")
        }
    }

    private func add() {
        guard let idea = store.addIdea(title: "新灵感") else { return }
        path = [idea.id]
    }
}

private struct IdeaDetail: View {
    @Environment(DaylineStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let idea: Idea
    @State private var title = ""
    @State private var bodyText = ""
    @State private var areaID: UUID?
    @State private var goalID: UUID?
    @State private var saveTask: Task<Void, Never>?
    @State private var createdTask: String?
    @State private var confirmDelete = false

    var body: some View {
        Form {
            Section {
                TextField("标题", text: $title, axis: .vertical)
                    .font(.title3.weight(.medium))
                    .accessibilityIdentifier("idea-title")
                TextField("写下来", text: $bodyText, axis: .vertical)
                    .lineLimit(6...16)
            }
            Section {
                Picker("领域", selection: $areaID) {
                    Text("无").tag(UUID?.none)
                    ForEach(store.areas, id: \.id) { Text($0.name).tag(Optional($0.id)) }
                }
                Picker("目标", selection: $goalID) {
                    Text("无").tag(UUID?.none)
                    ForEach(store.goals.filter { $0.status != .archived }, id: \.id) { Text($0.title).tag(Optional($0.id)) }
                }
                Toggle("置顶", isOn: Binding(get: { idea.isPinned }, set: { store.setIdeaPinned(idea, to: $0) }))
                Toggle("归档", isOn: Binding(get: { idea.isArchived }, set: { store.setIdeaArchived(idea, to: $0) }))
            }
            if let createdTask {
                Section { Text(createdTask).font(.footnote).foregroundStyle(.secondary) }
            }
            Section { Button("删除灵感", role: .destructive) { confirmDelete = true } }
        }
        .navigationTitle("灵感")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("转为任务", action: convert)
                    .accessibilityIdentifier("idea-convert")
            }
        }
        .onAppear {
            title = idea.title
            bodyText = idea.body
            areaID = idea.areaID
            goalID = idea.goalID
        }
        .onChange(of: title) { _, _ in scheduleSave() }
        .onChange(of: bodyText) { _, _ in scheduleSave() }
        .onChange(of: areaID) { _, _ in saveNow() }
        .onChange(of: goalID) { _, _ in saveNow() }
        .onDisappear { saveNow() }
        .confirmationDialog("删除这条灵感？", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("删除灵感", role: .destructive) { store.deleteIdea(idea); dismiss() }
            Button("取消", role: .cancel) {}
        }
        .accessibilityIdentifier("idea-detail")
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            saveNow()
        }
    }

    private func saveNow() {
        saveTask?.cancel()
        store.updateIdea(idea, title: title, body: bodyText, areaID: areaID, goalID: goalID)
    }

    private func convert() {
        saveNow()
        if let task = store.taskFromIdea(idea) {
            createdTask = "已创建任务「\(task.title)」，灵感仍保留。"
        }
    }
}
