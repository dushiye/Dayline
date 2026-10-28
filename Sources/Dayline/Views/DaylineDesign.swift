import SwiftUI
import DaylineCore
import DaylineData

// Quiet, system-native typography and surfaces adapt to the macOS appearance.
enum DaylineDesign {
    static let accent = Color(nsColor: NSColor(name: nil) { appearance in
        let rgb = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? DaylineBrand.accentDark : DaylineBrand.accentLight
        return NSColor(calibratedRed: rgb.red, green: rgb.green, blue: rgb.blue, alpha: 1)
    })
    static let pageInset: CGFloat = 44
    static let rowVerticalInset: CGFloat = 13
    static let pageTitle = Font.system(size: 32, weight: .bold)
    static let sectionTitle = Font.system(size: 12, weight: .semibold)
    static let taskTitle = Font.system(size: 14)
    static let canvas = Color(nsColor: .textBackgroundColor)
    static let line = Color.primary.opacity(0.065)
    static func color(_ key: String?) -> Color {
        if key == nil || key == "blue" { return accent }
        let rgb = DaylineBrand.area(key)
        return Color(red: rgb.red, green: rgb.green, blue: rgb.blue)
    }
}

/// A quiet secondary control that keeps native Button focus and activation behavior.
struct DaylineQuietButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @State private var hovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .padding(.horizontal, 11)
            .frame(minHeight: 32)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 9))
            .overlay {
                RoundedRectangle(cornerRadius: 9)
                    .fill(Color.primary.opacity(configuration.isPressed ? 0.12 : (hovering && isEnabled ? 0.055 : 0)))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 9).strokeBorder(Color.primary.opacity(0.07))
            }
            .opacity(isEnabled ? 1 : 0.45)
            .contentShape(RoundedRectangle(cornerRadius: 9))
            .onHover { hovering = $0 }
    }
}

/// Menu labels have an intrinsic width, so they don't expand across a toolbar or form.
struct DaylineMenuLabel: View {
    let title: String
    let symbol: String
    var caption: String? = nil
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: symbol).foregroundStyle(.secondary)
            if let caption { Text(caption).foregroundStyle(.secondary) }
            Text(title).lineLimit(1).frame(maxWidth: 150, alignment: .leading)
            Image(systemName: "chevron.down")
                .font(.system(size: 9, weight: .semibold)).foregroundStyle(.tertiary)
        }
        .font(.system(size: 12, weight: .medium))
        .padding(.horizontal, 11)
        .frame(minHeight: 32)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 9))
        .overlay { RoundedRectangle(cornerRadius: 9).fill(Color.primary.opacity(hovering ? 0.055 : 0)) }
        .overlay { RoundedRectangle(cornerRadius: 9).strokeBorder(Color.primary.opacity(0.07)) }
        .contentShape(RoundedRectangle(cornerRadius: 9))
        .fixedSize(horizontal: true, vertical: false)
        .onHover { hovering = $0 }
    }
}

extension TaskPriority {
    var label: String {
        switch self { case .none: return "无优先级"; case .low: return "低"; case .medium: return "中"; case .high: return "高" }
    }
    var color: Color {
        switch self { case .none: return .secondary; case .low: return .blue; case .medium: return .orange; case .high: return .red }
    }
}

extension RepeatRule {
    var label: String {
        switch self { case .none: return "不重复"; case .daily: return "每天"; case .weekly: return "每周" }
    }
}

struct QuietEmptyState: View {
    let symbol: String
    let title: String
    let detail: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    var body: some View {
        VStack(spacing: 13) {
            Image(systemName: symbol)
                .font(.system(size: 34, weight: .ultraLight))
                .foregroundStyle(DaylineDesign.accent.opacity(0.75))
                .padding(.bottom, 3)
            Text(title).font(.system(size: 18, weight: .medium))
            Text(detail).font(.system(size: 13)).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).lineSpacing(4).frame(maxWidth: 360)
            if let actionTitle, let action {
                Button(actionTitle, action: action).buttonStyle(.bordered).padding(.top, 6)
            }
        }.frame(maxWidth: .infinity).padding(.vertical, 60)
    }
}

struct SectionEyebrow: View {
    let title: String
    var count: Int? = nil
    var color: Color = .secondary
    var topSpacing: CGFloat = 20
    var body: some View {
        HStack(spacing: 8) {
            Text(title).font(DaylineDesign.sectionTitle).foregroundStyle(color)
            if let count { Text("\(count)").font(.system(size: 11, weight: .medium, design: .rounded)).foregroundStyle(.tertiary) }
            Spacer()
        }.padding(.top, topSpacing).padding(.bottom, 6)
    }
}
