import Foundation
import SwiftData

enum BodyPart: String, Codable, CaseIterable {
    case chest
    case back
    case legs
    case shoulders
    case arms
    case core
    case fullBody
}

@Model
final class Exercise {
    @Attribute(.unique) var id: UUID
    var name: String
    var bodyPart: BodyPart

    init(id: UUID = UUID(), name: String, bodyPart: BodyPart) {
        self.id = id
        self.name = name
        self.bodyPart = bodyPart
    }
}
