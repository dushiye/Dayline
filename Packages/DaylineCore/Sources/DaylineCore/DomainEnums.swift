import Foundation

public enum GoalKind: String, Codable, CaseIterable { case longTerm, shortTerm }
public enum GoalStatus: String, Codable, CaseIterable { case active, completed, archived }
public enum TaskPriority: Int, Codable, CaseIterable { case none = 0, low = 1, medium = 2, high = 3 }
public enum RepeatRule: String, Codable, CaseIterable { case none, daily, weekly }

/// Shared brand colors. Apps turn these into SwiftUI or AppKit colors.
public enum DaylineBrand {
    public struct RGB: Equatable, Sendable {
        public var red: Double
        public var green: Double
        public var blue: Double
        public init(red: Double, green: Double, blue: Double) {
            self.red = red
            self.green = green
            self.blue = blue
        }
    }

    public static let accentLight = RGB(red: 0.29, green: 0.43, blue: 0.88)
    public static let accentDark = RGB(red: 0.58, green: 0.68, blue: 0.98)

    public static func area(_ key: String?) -> RGB {
        switch key {
        case "purple": return RGB(red: 0.58, green: 0.49, blue: 0.75)
        case "green": return RGB(red: 0.40, green: 0.62, blue: 0.49)
        case "orange": return RGB(red: 0.77, green: 0.56, blue: 0.32)
        case "rose": return RGB(red: 0.74, green: 0.45, blue: 0.48)
        default: return accentLight
        }
    }
}
