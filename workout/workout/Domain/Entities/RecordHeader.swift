import Foundation
import SwiftData

@Model
final class RecordHeader {
    @Attribute(.unique) var id: UUID
    var date: Date
    var menu: Menu?
    var exercise: Exercise

    init(id: UUID = UUID(), date: Date, menu: Menu? = nil, exercise: Exercise) {
        self.id = id
        self.date = date
        self.menu = menu
        self.exercise = exercise
    }
}
