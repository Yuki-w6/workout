import Foundation
import SwiftData
import Testing
@testable import WorkoutLogJP2026WOD01

/// レビューで見つかった「削除が効かない/巻き戻る」系の回帰テスト。
@MainActor
struct ExerciseDeletionRegressionTests {
    private func insertPreset(
        _ preset: PresetExerciseDefinition,
        isArchived: Bool = false,
        into context: ModelContext
    ) -> Exercise {
        let exercise = Exercise(
            id: preset.id,
            name: preset.name,
            bodyPart: preset.bodyPart,
            defaultWeightUnit: preset.defaultWeightUnit,
            isPreset: true,
            seedKey: preset.seedKey,
            seedVersion: preset.seedVersion,
            isArchived: isArchived
        )
        context.insert(exercise)
        return exercise
    }

    /// 同一idの重複がある状態で削除しても、1件しかアーカイブされないと
    /// もう片方がfetchActive()で返り続け「削除したのに消えない」状態になる。
    @Test func archiveAppliesToEveryDuplicate() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let repository = SwiftDataExerciseRepository(context: context)
        let preset = PresetExerciseDefinitions.all[0]

        _ = insertPreset(preset, into: context)
        _ = insertPreset(preset, into: context)
        try context.save()

        try repository.archive(preset.id)

        #expect(try repository.fetchActive().isEmpty)
        #expect(try repository.fetchArchived().count == 2)
    }

    @Test func unarchiveAppliesToEveryDuplicate() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let repository = SwiftDataExerciseRepository(context: context)
        let preset = PresetExerciseDefinitions.all[0]

        _ = insertPreset(preset, isArchived: true, into: context)
        _ = insertPreset(preset, isArchived: true, into: context)
        try context.save()

        try repository.unarchive(preset.id)

        #expect(try repository.fetchActive().count == 2)
        #expect(try repository.fetchArchived().isEmpty)
    }

    /// upsertがisArchivedを書き戻すと、更新のついでに削除済み種目が復活する。
    @Test func upsertDoesNotResurrectAnArchivedExercise() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let repository = SwiftDataExerciseRepository(context: context)

        let exercise = Exercise(name: "自作種目", bodyPart: .chest, defaultWeightUnit: .kg)
        context.insert(exercise)
        try context.save()
        try repository.archive(exercise.id)

        // 別インスタンス(isArchived: false)で上書きを試みる。
        let incoming = Exercise(
            id: exercise.id,
            name: "自作種目（改名）",
            bodyPart: .chest,
            defaultWeightUnit: .kg
        )
        try repository.upsert(incoming)

        let stored = try #require(try repository.fetch(by: exercise.id))
        #expect(stored.name == "自作種目（改名）")
        #expect(stored.isArchived == true)
    }

    /// 重複解消でアーカイブ済みの側が消されると、削除操作そのものが巻き戻る。
    @Test func duplicateResolutionKeepsTheArchivedState() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let preset = PresetExerciseDefinitions.all[0]

        _ = insertPreset(preset, isArchived: true, into: context)
        _ = insertPreset(preset, isArchived: false, into: context)
        try context.save()

        try AppContainer.normalizePresetExercisesIfNeeded(context: context)

        let remaining = try context.fetch(FetchDescriptor<Exercise>())
        #expect(remaining.count == 1)
        #expect(remaining[0].isArchived == true)
    }

    /// 正規化はリモート変更のたびに走る。ユーザーの改名や単位変更を巻き戻してはいけない。
    @Test func normalizationKeepsUserEdits() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let preset = PresetExerciseDefinitions.all[0]

        let exercise = insertPreset(preset, into: context)
        exercise.name = "ベンチプレス（ワイド）"
        exercise.defaultWeightUnit = .lb
        try context.save()

        try AppContainer.normalizePresetExercisesIfNeeded(context: context)

        let stored = try #require(try context.fetch(FetchDescriptor<Exercise>()).first)
        #expect(stored.name == "ベンチプレス（ワイド）")
        #expect(stored.defaultWeightUnit == .lb)
        // 一方でプリセットとしての属性は維持される。
        #expect(stored.isPreset)
        #expect(stored.seedKey == preset.seedKey)
        #expect(stored.presetSortKey == 0)
    }

    /// プリセット行をタップする経路で、ユーザーの編集が定義値に巻き戻ってはいけない。
    @Test func tappingAPresetRowDoesNotOverwriteAnExistingExercise() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let repository = SwiftDataExerciseRepository(context: context)
        let preset = PresetExerciseDefinitions.all[0]

        let exercise = insertPreset(preset, into: context)
        exercise.name = "ベンチプレス（ワイド）"
        try context.save()

        let returned = AddExerciseUseCase(repository: repository).executePreset(preset)

        #expect(returned?.name == "ベンチプレス（ワイド）")
        #expect(try context.fetch(FetchDescriptor<Exercise>()).count == 1)
    }

    /// アーカイブ済みレコードだけが存在し、KVSが空(=別デバイス/別アカウント)の状態でも再投入しない。
    @Test func seederDoesNotReseedWhenOnlyAnArchivedRecordExists() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let preset = PresetExerciseDefinitions.all[0]

        _ = insertPreset(preset, isArchived: true, into: context)
        try context.save()

        let inserted = try PresetExerciseSeeder(
            context: context,
            keyStore: EmptyKeyStore(),
            definitions: [preset]
        ).seedIfNeeded()

        #expect(inserted.isEmpty)
        let stored = try context.fetch(FetchDescriptor<Exercise>())
        #expect(stored.count == 1)
        #expect(stored[0].isArchived == true)
    }
}

/// 毎回空を返す。CloudKit/KVSが未同期の端末を模す。
private final class EmptyKeyStore: SeededPresetKeyStore {
    func load() -> Set<String> { [] }
    func save(_ keys: Set<String>) {}
}
