import SwiftUI
import DaylineData

struct GoalsView: View {
    @Environment(DaylineStore.self) private var store
    @State private var editor: PhoneGoalRequest?

    private var active: [Goal] { store.goals.filter { $0.status != .archived } }
    private var longGoals: [Goal] { active.filter { $0.kind == .longTerm } }
    private var shortGoals: [Goal] {
        active.filter { goal in
            goal.kind == .shortTerm && (goal.parentGoalID == nil || !longGoals.contains { $0.id == goal.parentGoalID })
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if active.isEmpty {
                    PhoneEmpty(symbol: "scope", title: "你希望走向哪里？", detail: "用长期目标写下方向，再拆成短期成果。")
                } else {
                    List {
                        if !longGoals.isEmpty {
                            Section("长期目标") {
                                ForEach(longGoals, id: \.id) { goal in
                                    goalBlock(goal)
                                }
                            }
                        }
                        if !shortGoals.isEmpty {
                            Section("短期目标") {
                                ForEach(shortGoals, id: \.id) { goal in
                                    Button { editor = PhoneGoalRequest(goal: goal) } label: { GoalSummary(goal: goal) }
                                        .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("目标")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { editor = PhoneGoalRequest() } label: { Image(systemName: "plus") }
                        .accessibilityLabel("新建目标")
                }
            }
            .sheet(item: $editor) { PhoneGoalEditor(request: $0) }
            .accessibilityIdentifier("screen-goals")
        }
    }

    @ViewBuilder private func goalBlock(_ goal: Goal) -> some View {
        Button { editor = PhoneGoalRequest(goal: goal) } label: { GoalSummary(goal: goal) }
            .buttonStyle(.plain)
        let children = active.filter { $0.parentGoalID == goal.id && $0.kind == .shortTerm }
        ForEach(children, id: \.id) { child in
            Button { editor = PhoneGoalRequest(goal: child) } label: {
                GoalSummary(goal: child).padding(.leading, 18)
            }
            .buttonStyle(.plain)
        }
        Button { editor = PhoneGoalRequest(areaID: goal.areaID, parentGoalID: goal.id) } label: {
            Label("添加短期目标", systemImage: "plus")
                .font(.subheadline)
        }
    }
}

private struct GoalSummary: View {
    @Environment(DaylineStore.self) private var store
    let goal: Goal

    private var taskCount: Int { store.tasks.filter { $0.goalID == goal.id }.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Image(systemName: goal.kind == .longTerm ? "scope" : "flag")
                    .foregroundStyle(PhoneDesign.accent)
                Text(goal.title).font(.body.weight(.medium)).foregroundStyle(.primary)
                Spacer(minLength: 8)
                Text(goal.status.phoneLabel).font(.caption).foregroundStyle(.secondary)
            }
            ProgressView(value: min(max(goal.progress, 0), 1))
                .tint(goal.status == .completed ? .green : PhoneDesign.accent)
            HStack {
                Text("\(Int((goal.progress * 100).rounded()))%")
                if taskCount > 0 { Text("· \(taskCount) 项任务") }
                if let date = goal.targetDate {
                    Text("· \(date.formatted(.dateTime.month().day()))")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("goal-\(goal.title)")
    }
}
