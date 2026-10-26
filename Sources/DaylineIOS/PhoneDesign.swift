import SwiftUI
import UIKit
import DaylineCore
import DaylineData

enum PhoneTab: String, Hashable {
    case today, upcoming, inbox, goals, ideas

    static func fromLaunch() -> PhoneTab {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "--screen"), args.indices.contains(index + 1) else { return .today }
        return PhoneTab(rawValue: args[index + 1]) ?? .today
    }
}

enum PhoneDesign {
    static let accent = Color(uiColor: UIColor { trait in
        let rgb = trait.userInterfaceStyle == .dark ? DaylineBrand.accentDark : DaylineBrand.accentLight
        return UIColor(red: rgb.red, green: rgb.green, blue: rgb.blue, alpha: 1)
    })

    static func areaColor(_ key: String?) -> Color {
        if key == nil || key == "blue" { return accent }
        let rgb = DaylineBrand.area(key)
        return Color(red: rgb.red, green: rgb.green, blue: rgb.blue)
    }
}

extension RepeatRule {
    var phoneLabel: String {
        switch self { case .none: return "不重复"; case .daily: return "每天"; case .weekly: return "每周" }
    }
}

extension TaskPriority {
    var phoneLabel: String {
        switch self { case .none: return "无"; case .low: return "低"; case .medium: return "中"; case .high: return "高" }
    }
}

extension GoalKind {
    var phoneLabel: String { self == .longTerm ? "长期目标" : "短期目标" }
}

extension GoalStatus {
    var phoneLabel: String {
        switch self { case .active: return "进行中"; case .completed: return "已完成"; case .archived: return "已归档" }
    }
}

struct PhoneEmpty: View {
    let symbol: String
    let title: String
    let detail: String
    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: symbol)
        } description: {
            Text(detail)
        }
        .foregroundStyle(.secondary)
    }
}

struct QuickCaptureBar: View {
    let placeholder: String
    let identifier: String
    @Binding var text: String
    var submit: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "plus.circle.fill")
                .font(.title2)
                .foregroundStyle(PhoneDesign.accent)
                .accessibilityHidden(true)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .submitLabel(.done)
                .onSubmit(submit)
                .accessibilityIdentifier(identifier)
            if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button("添加", action: submit)
                    .font(.body.weight(.semibold))
                    .accessibilityIdentifier(identifier + "-submit")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06))
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }
}

enum PhoneTasks {
    @MainActor
    static func sorted(_ tasks: [DayTask]) -> [DayTask] {
        tasks.sorted {
            if $0.sortOrder != $1.sortOrder { return $0.sortOrder < $1.sortOrder }
            if $0.createdAt != $1.createdAt { return $0.createdAt < $1.createdAt }
            return $0.id.uuidString < $1.id.uuidString
        }
    }

    @MainActor
    static func open(_ store: DaylineStore) -> [DayTask] {
        sorted(store.tasks.filter { !$0.isCompleted })
    }

    @MainActor
    static func meta(_ task: DayTask, store: DaylineStore) -> String {
        var parts: [String] = []
        if let area = store.areas.first(where: { $0.id == task.areaID }) { parts.append(area.name) }
        if let goal = store.goals.first(where: { $0.id == task.goalID }) { parts.append(goal.title) }
        if let date = task.scheduledDate ?? task.dueDate {
            parts.append(date.formatted(.dateTime.month().day().weekday(.abbreviated)))
        }
        if task.repeatRule != .none { parts.append(task.repeatRule.phoneLabel) }
        return parts.joined(separator: " · ")
    }
}
