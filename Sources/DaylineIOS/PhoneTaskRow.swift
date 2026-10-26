import SwiftUI
import DaylineData

struct PhoneTaskRow: View {
    @Environment(DaylineStore.self) private var store
    let task: DayTask
    var onOpen: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Button {
                store.toggleTask(task)
            } label: {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(task.isCompleted ? PhoneDesign.accent : Color.secondary.opacity(0.55))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(task.isCompleted ? "取消完成 \(task.title)" : "完成 \(task.title)")

            Button(action: onOpen) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(task.title)
                        .font(.body)
                        .strikethrough(task.isCompleted, color: .secondary)
                        .foregroundStyle(task.isCompleted ? .secondary : .primary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    let detail = PhoneTasks.meta(task, store: store)
                    if !detail.isEmpty {
                        Text(detail)
                            .font(.subheadline)
                            .foregroundStyle(DaylineDates.isOverdue(task) && !task.isCompleted ? Color.orange : .secondary)
                            .lineLimit(2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if let area = store.areas.first(where: { $0.id == task.areaID }) {
                Circle()
                    .fill(PhoneDesign.areaColor(area.colorKey))
                    .frame(width: 8, height: 8)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("task-\(task.title)")
    }
}
