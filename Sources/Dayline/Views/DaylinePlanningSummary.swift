import SwiftUI

struct DaylinePlanningSummary: View {
    let report: PlanningReport
    @State private var window = 14
    private var summary: PlanningWindowSummary {
        window == 7 ? report.recent7 : window == 30 ? report.recent30 : report.recent14
    }
    var body: some View {
        DisclosureGroup("计划记录") {
            VStack(alignment: .leading, spacing: 12) {
                Picker("最近有效计划日", selection: $window) {
                    Text("7 天").tag(7); Text("14 天").tag(14); Text("30 天").tag(30)
                }.pickerStyle(.segmented).frame(width: 220)
                Text("已积累 \(summary.dayCount) 个有效计划日")
                    .font(.system(size: 12, weight: .medium))
                if summary.dayCount > 0 {
                    Text("计划 \(summary.planned) 项 · 实际完成 \(summary.actualCompleted) 项 · 原计划完成 \(summary.originalCompleted) 项")
                    Text("当天新增 \(summary.addedToday) 项 · 主动改期 \(summary.activelyRescheduled) 项 · 删除 \(summary.deleted) 项")
                    ForEach(summary.days.reversed()) { day in
                        HStack {
                            Text(day.dayKey).monospacedDigit()
                            Spacer()
                            Text("计划 \(day.planned) · 完成 \(day.actualCompleted) · 原计划完成 \(day.originalCompleted)")
                        }
                    }
                } else {
                    Text("从本次升级开始记录。历史不足 7 个有效计划日时，不提供容量建议。")
                }
                Text("原计划指当天开始前已安排的任务；当天新安排单独计数。改期或删除会保留历史记录。升级当日的基线不用于容量建议。")
                    .foregroundStyle(.tertiary).fixedSize(horizontal: false, vertical: true)
            }.font(.system(size: 11)).foregroundStyle(.secondary).padding(.vertical, 12)
        }.font(.system(size: 12)).foregroundStyle(.secondary).padding(.top, 24)
    }
}
