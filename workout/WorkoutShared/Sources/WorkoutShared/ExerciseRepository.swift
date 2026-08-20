import Foundation
import SwiftData

public enum ExerciseRepositoryError: Error {
    case hasRecords
}

// MARK: - Protocol

public protocol ExerciseRepository {
    // 基本
    func fetchAll(includeArchived: Bool) throws -> [Exercise]
    func fetchActive() throws -> [Exercise]               // isArchived == false
    func fetchArchived() throws -> [Exercise]             // isArchived == true

    // 検索・絞り込み
    func fetch(by id: UUID) throws -> Exercise?
    func fetchByBodyPart(_ bodyPart: BodyPart, includeArchived: Bool) throws -> [Exercise]
    func searchByName(_ keyword: String, includeArchived: Bool) throws -> [Exercise]

    // 更新系
    func upsert(_ exercise: Exercise) throws
    func archive(_ exerciseID: UUID) throws
    func unarchive(_ exerciseID: UUID) throws

    // (原則使わない) 物理削除：必要になった場合のみ
    func deletePermanently(_ exerciseID: UUID) throws
}

// MARK: - Implementation

public final class SwiftDataExerciseRepository: ExerciseRepository {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    // MARK: Fetch

    public func fetchAll(includeArchived: Bool = true) throws -> [Exercise] {
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

    public func fetchActive() throws -> [Exercise] {
        try fetchAll(includeArchived: false)
    }

    public func fetchArchived() throws -> [Exercise] {
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

    public func fetch(by id: UUID) throws -> Exercise? {
        try fetchAllMatching(id).first
    }

    // CloudKitは一意制約を持たないため、同じidのレコードが複数同期され得る。
    // 更新・アーカイブを1件にしか適用しないと、もう片方がfetchActive()で返り続けて
    // 「削除したのに消えない・エラーも出ない」状態になるので、必ず全件に適用する。
    private func fetchAllMatching(_ id: UUID) throws -> [Exercise] {
        let desc = FetchDescriptor<Exercise>(
            predicate: #Predicate { $0.id == id }
        )
        return try context.fetch(desc)
    }

    public func fetchByBodyPart(_ bodyPart: BodyPart, includeArchived: Bool = false) throws -> [Exercise] {
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

    public func searchByName(_ keyword: String, includeArchived: Bool = false) throws -> [Exercise] {
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

    // MARK: Mutations

    public func upsert(_ exercise: Exercise) throws {
        // SwiftDataはinsert済みオブジェクトを再insertしても問題になりにくいですが、
        // 参照が別インスタンスの場合に備え、IDで既存を探して更新するのが安全。
        let existing = try fetchAllMatching(exercise.id)
        if existing.isEmpty {
            context.insert(exercise)
        } else {
            for target in existing {
                target.name = exercise.name
                target.bodyPartRaw = exercise.bodyPartRaw
                target.defaultWeightUnitRaw = exercise.defaultWeightUnitRaw
                target.isPreset = exercise.isPreset
                target.presetSortKey = exercise.isPreset ? 0 : 1
                target.seedKey = exercise.seedKey
                target.seedVersion = exercise.seedVersion
                // isArchivedは意図的に触らない。
                // 削除済みの種目が更新のついでに復活するため、復活はunarchive()に限定する。
            }
        }
        try context.save()
    }

    public func archive(_ exerciseID: UUID) throws {
        let targets = try fetchAllMatching(exerciseID)
        guard targets.isEmpty == false else { return }
        if try hasRecords(for: exerciseID) {
            throw ExerciseRepositoryError.hasRecords
        }
        for target in targets {
            target.isArchived = true
        }
        try context.save()
    }

    public func unarchive(_ exerciseID: UUID) throws {
        let targets = try fetchAllMatching(exerciseID)
        guard targets.isEmpty == false else { return }
        for target in targets {
            target.isArchived = false
        }
        try context.save()
    }

    public func deletePermanently(_ exerciseID: UUID) throws {
        // 原則は使わない（履歴参照を壊す可能性があるため）
        for target in try fetchAllMatching(exerciseID) {
            context.delete(target)
        }
        try context.save()
    }

    private func hasRecords(for exerciseID: UUID) throws -> Bool {
        let desc = FetchDescriptor<RecordHeader>(
            predicate: #Predicate { $0.exerciseIDSnapshot == exerciseID }
        )
        // sets が0件のヘッダー(Watch側の先行作成等)は「記録がある」に数えない。
        return try context.fetch(desc).contains { $0.hasRecordedSets }
    }
}
