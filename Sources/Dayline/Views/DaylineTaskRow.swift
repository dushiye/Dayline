import SwiftUI
import DaylineCore
import DaylineData

struct DaylineTaskRow: View {
    let task: DayTask
    let area: Area?
    let goal: Goal?
    let carryover: Bool
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onToday: () -> Void
    @State private var hovered = false

    private var showSchedule: Bool {
        guard let date = task.scheduledDate else { return false }
        return carryover || !Calendar.current.isDateInToday(date)
            || (task.dueDate.map { !Calendar.current.isDate(date, inSameDayAs: $0) } ?? false)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .light))
                    .foregroundStyle(task.isCompleted ? DaylineDesign.accent : (task.priority == .none ? Color.secondary.opacity(0.55) : task.priority.color))
            }.buttonStyle(.plain).help(task.isCompleted ? "标记为未完成" : "完成任务")
                .accessibilityLabel(task.isCompleted ? "恢复任务：\(task.title)" : "完成任务：\(task.title)")
            Button(action: onEdit) {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 7) {
                        Text(task.title).font(DaylineDesign.taskTitle).foregroundStyle(task.isCompleted ? .secondary : .primary)
                            .strikethrough(task.isCompleted, color: .secondary.opacity(0.5)).lineLimit(2)
                        if task.priority != .none && !task.isCompleted {
                            Image(systemName: "flag.fill").font(.system(size: 9)).foregroundStyle(task.priority.color)
                        }
                        if !task.notes.isEmpty { Image(systemName: "text.alignleft").font(.system(size: 9)).foregroundStyle(.tertiary) }
                        if task.repeatRule != .none { Image(systemName: "repeat").font(.system(size: 10)).foregroundStyle(.tertiary) }
                    }
                    if goal != nil || task.dueDate != nil || carryover || showSchedule {
                        HStack(spacing: 10) {
                            if let goal { Text(goal.title).lineLimit(1) }
                            if let due = task.dueDate {
                                Label("截止 \(due.formatted(.dateTime.month().day()))", systemImage: "flag")
                                    .foregroundStyle(DaylineDates.isOverdue(task) ? .orange : .secondary)
                            }
                            if let date = task.scheduledDate, showSchedule {
                                Label("计划 \(date.formatted(.dateTime.month().day()))", systemImage: "calendar")
                            }
                        }.font(.system(size: 10)).foregroundStyle(.secondary)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
            }.buttonStyle(.plain).help("编辑任务")
            if carryover {
                Button("今天") { onToday() }.buttonStyle(.bordered).controlSize(.small).help("将计划日期改为今天；截止日期保持不变")
            } else {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 10)).foregroundStyle(.tertiary)
                    .frame(width: 14).opacity(hovered ? 1 : 0)
                    .help("拖动以调整顺序").accessibilityHidden(true)
            }
        }.padding(.vertical, carryover ? 9 : DaylineDesign.rowVerticalInset).padding(.horizontal, 5)
            .background(hovered ? Color.primary.opacity(0.025) : Color.clear, in: RoundedRectangle(cornerRadius: 7))
            .onHover { hovered = $0 }
    }
}
