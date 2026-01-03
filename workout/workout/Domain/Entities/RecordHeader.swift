import Foundation
import SwiftData

@Model
final class RecordHeader {
    @Attribute(.unique) var id: UUID
    var date: Date
    var menu: Menu?
    var exercise: Exercise
    @Relationship(deleteRule: .cascade) var details: [RecordDetail]

    init(
        id: UUID = UUID(),
        date: Date,
        menu: Menu? = nil,
        exercise: Exercise,
        details: [RecordDetail] = []
    ) {
        self.id = id
        self.date = date
        self.menu = menu
        self.exercise = exercise
        self.details = details
    }
}
