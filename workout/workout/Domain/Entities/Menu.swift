import Foundation
import SwiftData

@Model
final class Menu {
    @Attribute(.unique) var id: UUID
    var name: String
    var exercises: [Exercise]

    init(id: UUID = UUID(), name: String, exercises: [Exercise]) {
        self.id = id
        self.name = name
        self.exercises = exercises
    }
}
