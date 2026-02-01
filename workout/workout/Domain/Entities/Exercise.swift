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
    case fullBody
    case other
}

enum WeightUnit: String, Codable, CaseIterable {
    case kg
    case lb
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
        case .fullBody:
            return "全身"
        case .other:
            return "その他"
        }
    }
}

extension WeightUnit {
    var displayName: String {
        switch self {
        case .kg: 
            return "kg"
        case .lb:
            return "lbs"
        }
    }
}

@Model
final class Exercise {
    var id: UUID = UUID()
    var name: String = ""
    
    // enumはrawで保存（将来case追加/名前変更しても事故りにくい）
    var bodyPartRaw: String = BodyPart.other.rawValue
    var defaultWeightUnitRaw: String = WeightUnit.kg.rawValue
    
    // プリセット判定
    var isPreset: Bool = false
    
    // プリセット更新用（プリセットは必須、ユーザー作成はnil）
    var seedKey: String?
    var seedVersion: Int = 0
    
    // 論理削除（アーカイブ）
    var isArchived: Bool = false
    
    var presetSortKey: Int = 1
    
    @Relationship
    var templateSets: [ExerciseTemplateSet]? = []
    
    @Relationship
    var recordHeaders: [RecordHeader]? = []

    init(
        id: UUID = UUID(),
        name: String,
        bodyPart: BodyPart,
        defaultWeightUnit: WeightUnit,
        isPreset: Bool = false,
        seedKey: String? = nil,
        seedVersion: Int = 0,
        isArchived: Bool = false
    ) {
        // 運用ルールをモデル内で強制（崩れたデータを作らせない）
        if isPreset {
            precondition(seedKey != nil && !seedKey!.isEmpty, "Preset exercise must have seedKey")
        } else {
            precondition(seedKey == nil, "User exercise must not have seedKey")
        }
        
        self.id = id
        self.name = name
        self.bodyPartRaw = bodyPart.rawValue
        self.defaultWeightUnitRaw = defaultWeightUnit.rawValue
        self.isPreset = isPreset
        self.seedKey = seedKey
        self.seedVersion = seedVersion
        self.isArchived = isArchived
        
        self.presetSortKey = isPreset ? 0 : 1
    }
    
    var bodyPart: BodyPart {
        get { BodyPart(rawValue: bodyPartRaw) ?? .other }
        set { bodyPartRaw = newValue.rawValue }
    }
    
    var defaultWeightUnit: WeightUnit {
        get { WeightUnit(rawValue: defaultWeightUnitRaw) ?? .kg }
        set { defaultWeightUnitRaw = newValue.rawValue }
    }
}
