import Foundation
import SwiftData

@Model
final class Menu {
    var id: UUID = UUID()
    var name: String = ""
    var exercises: [Exercise]?

    init(id: UUID = UUID(), name: String, exercises: [Exercise] = []) {
        self.id = id
        self.name = name
        self.exercises = exercises
    }
}
