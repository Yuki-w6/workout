import Foundation
import SwiftData

@MainActor
final class ExerciseListViewModel: ObservableObject {
    @Published private(set) var loadedExercises: [Exercise] = []

    /// ❗ 画面に渡す前に、削除済みのインスタンスを必ず外す。
    ///
    /// AppContainerは「アプリがアクティブに戻ったとき」と「リモート変更が届いたとき」に
    /// 重複した種目を削除する。削除はこの配列に反映されないため、load()し直すまでの間、
    /// 配列には無効になったインスタンスが残る。そこに画面が触れるとSwiftDataが停止する。
    ///
    /// 触る側(一覧・グラフ・検索)を1つずつ直すと必ず取りこぼすので、配る側で1回だけ弾く。
    var exercises: [Exercise] {
        loadedExercises.filter { !$0.isDeleted && $0.modelContext != nil }
    }

    // プリセット行の抑止判定はアーカイブ済みも含めて行う。
    // アクティブな種目だけで判定すると、削除した種目が「未作成のプリセット」として
    // すぐに再表示され、タップすると復活してしまう。
    private var materializedPresetIDs: Set<UUID> = []
    private var materializedSeedKeys: Set<String> = []

    private let fetchExercises: FetchExercisesUseCase
    private let fetchExerciseUseCase: FetchExerciseUseCase
    private let addExercise: AddExerciseUseCase
    private let updateExerciseUseCase: UpdateExerciseUseCase
    private let deleteExerciseUseCase: DeleteExerciseUseCase
    private let fetchArchivedExercises: FetchArchivedExercisesUseCase
    private let restoreExerciseUseCase: RestoreExerciseUseCase

    init(
        fetchExercises: FetchExercisesUseCase,
        fetchExercise: FetchExerciseUseCase,
        addExercise: AddExerciseUseCase,
        updateExercise: UpdateExerciseUseCase,
        deleteExercise: DeleteExerciseUseCase,
        fetchArchivedExercises: FetchArchivedExercisesUseCase,
        restoreExercise: RestoreExerciseUseCase
    ) {
        self.fetchExercises = fetchExercises
        self.fetchExerciseUseCase = fetchExercise
        self.addExercise = addExercise
        self.updateExerciseUseCase = updateExercise
        self.deleteExerciseUseCase = deleteExercise
        self.fetchArchivedExercises = fetchArchivedExercises
        self.restoreExerciseUseCase = restoreExercise
    }

    func load() {
        loadedExercises = dedupeByID(fetchExercises.execute())

        let allExercises = fetchExercises.execute(includeArchived: true)
        materializedPresetIDs = Set(allExercises.filter { $0.isPreset }.map { $0.id })
        materializedSeedKeys = Set(allExercises.compactMap { $0.seedKey })
    }

    func exercises(matching searchText: String) -> [Exercise] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return exercises }
        return exercises.filter { $0.name.localizedCaseInsensitiveContains(trimmed) }
    }

    func availablePresets(matching searchText: String) -> [PresetExerciseDefinition] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return PresetExerciseDefinitions.all.filter { preset in
            guard materializedPresetIDs.contains(preset.id) == false else { return false }
            guard materializedSeedKeys.contains(preset.seedKey) == false else { return false }
            guard !trimmed.isEmpty else { return true }
            return preset.name.localizedCaseInsensitiveContains(trimmed)
        }
    }

    func ensureExercise(for preset: PresetExerciseDefinition) -> Exercise? {
        if let existingByID = exercises.first(where: { $0.id == preset.id }) {
            return existingByID
        }
        if let existingBySeed = exercises.first(where: { $0.seedKey == preset.seedKey }) {
            return existingBySeed
        }
        let created = addExercise.executePreset(preset)
        load()
        return created
    }

    func archivedExercises() -> [Exercise] {
        dedupeByID(fetchArchivedExercises.execute())
    }

    func restoreExercise(id: UUID) {
        restoreExerciseUseCase.execute(id: id)
        load()
    }

    func exercise(id: UUID) -> Exercise? {
        fetchExerciseUseCase.execute(id: id)
    }

    func addExercise(name: String, bodyPart: BodyPart) {
        _ = addExercise.execute(name: name, bodyPart: bodyPart)
        load()
    }

    func updateExercise(id: UUID, name: String, bodyPart: BodyPart) {
        _ = updateExerciseUseCase.execute(id: id, name: name, bodyPart: bodyPart)
        load()
    }

    func deleteExercises(at offsets: IndexSet) -> [UUID] {
        let ids = offsets.compactMap { index in
            exercises.indices.contains(index) ? exercises[index].id : nil
        }
        return deleteExercises(ids: ids)
    }

    func deleteExercises(ids: [UUID]) -> [UUID] {
        var failedIds: [UUID] = []
        for id in ids {
            let deleted = deleteExerciseUseCase.execute(id: id)
            if !deleted {
                failedIds.append(id)
            }
        }
        load()
        return failedIds
    }

    private func dedupeByID(_ items: [Exercise]) -> [Exercise] {
        var seen: Set<UUID> = []
        var result: [Exercise] = []
        result.reserveCapacity(items.count)
        for item in items {
            if seen.insert(item.id).inserted {
                result.append(item)
            }
        }
        return result
    }
}
