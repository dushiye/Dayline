import Foundation

struct IdeaRecord: Codable {
    var id: UUID
    var title: String
    var body: String
    var createdAt: Date
    var updatedAt: Date
    var isPinned: Bool
    var isArchived: Bool
    var areaID: UUID?
    var goalID: UUID?

    init(_ idea: Idea) {
        id = idea.id; title = idea.title; body = idea.body
        createdAt = idea.createdAt; updatedAt = idea.updatedAt
        isPinned = idea.isPinned; isArchived = idea.isArchived
        areaID = idea.areaID; goalID = idea.goalID
    }
    func model() -> Idea {
        Idea(id: id, title: title, body: body, createdAt: createdAt, updatedAt: updatedAt,
             isPinned: isPinned, isArchived: isArchived, areaID: areaID, goalID: goalID)
    }
    func apply(to idea: Idea) {
        idea.title = title; idea.body = body; idea.createdAt = createdAt; idea.updatedAt = updatedAt
        idea.isPinned = isPinned; idea.isArchived = isArchived; idea.areaID = areaID; idea.goalID = goalID
    }
}
