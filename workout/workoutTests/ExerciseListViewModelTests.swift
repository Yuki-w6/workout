import Foundation
import SwiftData
import Testing
@testable import WorkoutLogJP2026WOD01

private final class InMemoryKeyStore: SeededPresetKeyStore {
    private var keys: Set<String> = []

    func load() -> Set<String> { keys }
    func save(_ keys: Set<String>) { self.keys = keys }
}

@MainActor
struct ExerciseListViewModelTests {
    private func makeViewModel(repository: ExerciseRepository) -> ExerciseListViewModel {
        ExerciseListViewModel(
            fetchExercises: FetchExercisesUseCase(repository: repository),
            fetchExercise: FetchExerciseUseCase(repository: repository),
            addExercise: AddExerciseUseCase(repository: repository),
            updateExercise: UpdateExerciseUseCase(repository: repository),
            deleteExercise: DeleteExerciseUseCase(repository: repository),
            fetchArchivedExercises: FetchArchivedExercisesUseCase(repository: repository),
            restoreExercise: RestoreExerciseUseCase(repository: repository)
        )
    }

    /// シード後はプリセットがすべて実体化しているので、追加候補のプリセット行は出ない。
    @Test func offersNoPresetRowsAfterSeeding() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        try PresetExerciseSeeder(context: context, keyStore: InMemoryKeyStore()).seedIfNeeded()

        let viewModel = makeViewModel(repository: SwiftDataExerciseRepository(context: context))
        viewModel.load()

        #expect(viewModel.availablePresets(matching: "").isEmpty)
        #expect(viewModel.exercises.count == PresetExerciseDefinitions.all.count)
    }

    /// 削除(アーカイブ)した種目が、未作成のプリセットとして再表示されないこと。
    @Test func doesNotOfferAnArchivedPresetAgain() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        try PresetExerciseSeeder(context: context, keyStore: InMemoryKeyStore()).seedIfNeeded()

        let viewModel = makeViewModel(repository: SwiftDataExerciseRepository(context: context))
        viewModel.load()

        let target = PresetExerciseDefinitions.all[0]
        let failedIDs = viewModel.deleteExercises(ids: [target.id])

        #expect(failedIDs.isEmpty)
        #expect(viewModel.exercises.contains { $0.id == target.id } == false)
        #expect(viewModel.availablePresets(matching: "").contains { $0.seedKey == target.seedKey } == false)
        #expect(viewModel.availablePresets(matching: "").isEmpty)
    }

    /// 実体が1件も無い状態(=シード前の旧データ)では、従来どおりプリセット行を出す。
    @Test func offersPresetRowsWhenNothingIsMaterialized() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)

        let viewModel = makeViewModel(repository: SwiftDataExerciseRepository(context: context))
        viewModel.load()

        #expect(viewModel.availablePresets(matching: "").count == PresetExerciseDefinitions.all.count)
    }
}
