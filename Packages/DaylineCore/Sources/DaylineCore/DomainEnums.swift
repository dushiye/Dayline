import Foundation

public enum GoalKind: String, Codable, CaseIterable { case longTerm, shortTerm }
public enum GoalStatus: String, Codable, CaseIterable { case active, completed, archived }
public enum TaskPriority: Int, Codable, CaseIterable { case none = 0, low = 1, medium = 2, high = 3 }
public enum RepeatRule: String, Codable, CaseIterable { case none, daily, weekly }
