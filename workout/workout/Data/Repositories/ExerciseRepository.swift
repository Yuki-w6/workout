import Foundation
import SwiftData

enum ExerciseRepositoryError: Error {
    case hasRecords
}

// MARK: - Protocol

protocol ExerciseRepository {
    // 基本
    func fetchAll(includeArchived: Bool) throws -> [Exercise]
    func fetchActive() throws -> [Exercise]               // isArchived == false
    func fetchArchived() throws -> [Exercise]             // isArchived == true
    
    // 検索・絞り込み
    func fetch(by id: UUID) throws -> Exercise?
    func fetchByBodyPart(_ bodyPart: BodyPart, includeArchived: Bool) throws -> [Exercise]
    func searchByName(_ keyword: String, includeArchived: Bool) throws -> [Exercise]
    
    // seed / 同期のための取得
    func fetchPresetBySeedKey(_ seedKey: String) throws -> Exercise?
    func fetchPresets() throws -> [Exercise]
    
    // 更新系
    func upsert(_ exercise: Exercise) throws
    func archive(_ exerciseID: UUID) throws
    func unarchive(_ exerciseID: UUID) throws
    
    // (原則使わない) 物理削除：必要になった場合のみ
    func deletePermanently(_ exerciseID: UUID) throws
}

// MARK: - Implementation

final class SwiftDataExerciseRepository: ExerciseRepository {
    private let context: ModelContext
    
    init(context: ModelContext) {
        self.context = context
    }
    
    // MARK: Fetch
    
    func fetchAll(includeArchived: Bool = true) throws -> [Exercise] {
        let desc = FetchDescriptor<Exercise>(
            predicate: includeArchived ? nil : #Predicate { $0.isArchived == false },
            sortBy: [
                SortDescriptor(\Exercise.presetSortKey, order: .forward),
                SortDescriptor(\Exercise.bodyPartRaw, order: .forward),
                SortDescriptor(\Exercise.name, order: .forward)
            ]
        )
        return try context.fetch(desc)
    }
    
    func fetchActive() throws -> [Exercise] {
        try fetchAll(includeArchived: false)
    }
    
    func fetchArchived() throws -> [Exercise] {
        let desc = FetchDescriptor<Exercise>(
            predicate: #Predicate { $0.isArchived == true },
            sortBy: [
                SortDescriptor(\Exercise.presetSortKey, order: .forward),
                SortDescriptor(\Exercise.bodyPartRaw, order: .forward),
                SortDescriptor(\Exercise.name, order: .forward)
            ]
        )
        return try context.fetch(desc)
    }
    
    func fetch(by id: UUID) throws -> Exercise? {
        let desc = FetchDescriptor<Exercise>(
            predicate: #Predicate { $0.id == id }
        )
        return try context.fetch(desc).first
    }
    
    func fetchByBodyPart(_ bodyPart: BodyPart, includeArchived: Bool = false) throws -> [Exercise] {
        let bodyPartRaw = bodyPart.rawValue
        let predicate: Predicate<Exercise> = includeArchived
        ? #Predicate { $0.bodyPartRaw == bodyPartRaw }
        : #Predicate { $0.bodyPartRaw == bodyPartRaw && $0.isArchived == false }
        
        let desc = FetchDescriptor<Exercise>(
            predicate: predicate,
            sortBy: [
                SortDescriptor(\Exercise.presetSortKey, order: .forward),
                SortDescriptor(\Exercise.name, order: .forward)
            ]
        )
        return try context.fetch(desc)
    }
    
    func searchByName(_ keyword: String, includeArchived: Bool = false) throws -> [Exercise] {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return try fetchAll(includeArchived: includeArchived)
        }
        
        // SwiftDataのPredicateでcontainsが使える（大文字小文字の扱いは要件次第）
        let predicate: Predicate<Exercise> = includeArchived
        ? #Predicate { $0.name.contains(trimmed) }
        : #Predicate { $0.name.contains(trimmed) && $0.isArchived == false }
        
        let desc = FetchDescriptor<Exercise>(
            predicate: predicate,
            sortBy: [
                SortDescriptor(\Exercise.presetSortKey, order: .forward),
                SortDescriptor(\Exercise.name, order: .forward)
            ]
        )
        return try context.fetch(desc)
    }
    
    // MARK: Preset / Seed
    
    func fetchPresetBySeedKey(_ seedKey: String) throws -> Exercise? {
        let key = seedKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return nil }
        
        let desc = FetchDescriptor<Exercise>(
            predicate: #Predicate { $0.isPreset == true && $0.seedKey == key }
        )
        return try context.fetch(desc).first
    }
    
    func fetchPresets() throws -> [Exercise] {
        let desc = FetchDescriptor<Exercise>(
            predicate: #Predicate { $0.isPreset == true && $0.isArchived == false },
            sortBy: [
                SortDescriptor(\Exercise.bodyPartRaw, order: .forward),
                SortDescriptor(\Exercise.name, order: .forward)
            ]
        )
        return try context.fetch(desc)
    }
    
    // MARK: Mutations
    
    func upsert(_ exercise: Exercise) throws {
        // SwiftDataはinsert済みオブジェクトを再insertしても問題になりにくいですが、
        // 参照が別インスタンスの場合に備え、IDで既存を探して更新するのが安全。
        if let existing = try fetch(by: exercise.id) {
            existing.name = exercise.name
            existing.bodyPartRaw = exercise.bodyPartRaw
            existing.defaultWeightUnitRaw = exercise.defaultWeightUnitRaw
            existing.isPreset = exercise.isPreset
            existing.seedKey = exercise.seedKey
            existing.seedVersion = exercise.seedVersion
            existing.isArchived = exercise.isArchived
        } else {
            context.insert(exercise)
        }
        try context.save()
    }
    
    func archive(_ exerciseID: UUID) throws {
        guard let ex = try fetch(by: exerciseID) else { return }
        if try hasRecords(for: exerciseID) {
            throw ExerciseRepositoryError.hasRecords
        }
        ex.isArchived = true
        try context.save()
    }
    
    func unarchive(_ exerciseID: UUID) throws {
        guard let ex = try fetch(by: exerciseID) else { return }
        ex.isArchived = false
        try context.save()
    }
    
    func deletePermanently(_ exerciseID: UUID) throws {
        // 原則は使わない（履歴参照を壊す可能性があるため）
        guard let ex = try fetch(by: exerciseID) else { return }
        context.delete(ex)
        try context.save()
    }

    private func hasRecords(for exerciseID: UUID) throws -> Bool {
        var desc = FetchDescriptor<RecordHeader>(
            predicate: #Predicate { $0.exerciseIDSnapshot == exerciseID }
        )
        desc.fetchLimit = 1
        return try context.fetch(desc).isEmpty == false
    }

    private let presetFirstComparator: (Bool, Bool) -> ComparisonResult = { lhs, rhs in
        if lhs == rhs { return .orderedSame }
        return lhs ? .orderedAscending : .orderedDescending
    }
}
