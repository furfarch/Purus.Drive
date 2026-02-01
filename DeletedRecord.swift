import Foundation
import SwiftData

@Model
final class DeletedRecord {
    @Attribute(.unique) var id: UUID
    var entityType: String
    var deletedAt: Date

    init(entityType: String, id: UUID, deletedAt: Date = .now) {
        self.entityType = entityType
        self.id = id
        self.deletedAt = deletedAt
    }
}
