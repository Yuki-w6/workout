import Foundation
import SwiftData

@Model
final class RecordHeader {
    var id: UUID = UUID()
    var date: Date = Date()
    @Relationship(inverse: \Exercise.recordHeaders) var exercise: Exercise?
    @Relationship(deleteRule: .cascade, inverse: \RecordDetail.header) var details: [RecordDetail]?

    init(
        id: UUID = UUID(),
        date: Date,
        exercise: Exercise,
        details: [RecordDetail] = []
    ) {
        self.id = id
        self.date = date
        self.exercise = exercise
        self.details = details
    }
}
