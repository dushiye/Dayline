import Foundation

public struct IdeaRecord: Codable {
    public var id: UUID
    public var title: String
    public var body: String
    public var createdAt: Date
    public var updatedAt: Date
    public var isPinned: Bool
    public var isArchived: Bool
    public var areaID: UUID?
    public var goalID: UUID?

    public init(_ idea: Idea) {
        id = idea.id; title = idea.title; body = idea.body
        createdAt = idea.createdAt; updatedAt = idea.updatedAt
        isPinned = idea.isPinned; isArchived = idea.isArchived
        areaID = idea.areaID; goalID = idea.goalID
    }
    public func model() -> Idea {
        Idea(id: id, title: title, body: body, createdAt: createdAt, updatedAt: updatedAt,
             isPinned: isPinned, isArchived: isArchived, areaID: areaID, goalID: goalID)
    }
    public func apply(to idea: Idea) {
        idea.title = title; idea.body = body; idea.createdAt = createdAt; idea.updatedAt = updatedAt
        idea.isPinned = isPinned; idea.isArchived = isArchived; idea.areaID = areaID; idea.goalID = goalID
    }
}
