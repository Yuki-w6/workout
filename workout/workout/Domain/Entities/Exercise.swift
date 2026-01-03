import Foundation
import SwiftData

enum BodyPart: String, Codable, CaseIterable {
    case chest
    case back
    case legs
    case shoulders
    case arms
    case glutes
    case core
}

enum WeightUnit: String, Codable, CaseIterable {
    case kg
    case lbs
}

@Model
final class ExerciseSet {
    @Attribute(.unique) var id: UUID
    var order: Int
    var weight: String
    var reps: String
    var memo: String

    init(id: UUID = UUID(), order: Int = 0, weight: String, reps: String, memo: String) {
        self.id = id
        self.order = order
        self.weight = weight
        self.reps = reps
        self.memo = memo
    }
}

extension BodyPart {
    var displayName: String {
        switch self {
        case .chest:
            return "胸"
        case .back:
            return "背中"
        case .legs:
            return "脚"
        case .shoulders:
            return "肩"
        case .arms:
            return "腕"
        case .glutes:
            return "お尻"
        case .core:
            return "お腹"
        }
    }
}

@Model
final class Exercise {
    @Attribute(.unique) var id: UUID
    var name: String
    var bodyPart: BodyPart
    var weightUnit: WeightUnit
    @Relationship(deleteRule: .cascade) var sets: [ExerciseSet]

    init(
        id: UUID = UUID(),
        name: String,
        bodyPart: BodyPart,
        weightUnit: WeightUnit = .kg,
        sets: [ExerciseSet] = []
    ) {
        self.id = id
        self.name = name
        self.bodyPart = bodyPart
        self.weightUnit = weightUnit
        self.sets = sets
    }
}
