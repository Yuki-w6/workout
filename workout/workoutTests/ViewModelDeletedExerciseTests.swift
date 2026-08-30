import Foundation
import SwiftData
import Testing
@testable import WorkoutLogJP2026WOD01

/// 全画面広告を閉じた直後にアプリが落ちた件の回帰テスト。
///
/// 広告を閉じるとアプリがアクティブに戻り、AppContainerの正規化が重複した種目を削除する。
/// ViewModelが保持している配列には削除済みのインスタンスが残るため、
/// 画面がそれに触れるとSwiftDataが停止する。
/// 触る側を1つずつ直すと取りこぼすので、配る側で弾く。
@MainActor
struct ViewModelDeletedExerciseTests {
    private func makeViewModel(context: ModelContext) -> ExerciseListViewModel {
        let repository = SwiftDataExerciseRepository(context: context)
        return ExerciseListViewModel(
            fetchExercises: FetchExercisesUseCase(repository: repository),
            fetchExercise: FetchExerciseUseCase(repository: repository),
            addExercise: AddExerciseUseCase(repository: repository),
            updateExercise: UpdateExerciseUseCase(repository: repository),
            deleteExercise: DeleteExerciseUseCase(repository: repository),
            fetchArchivedExercises: FetchArchivedExercisesUseCase(repository: repository),
            restoreExercise: RestoreExerciseUseCase(repository: repository)
        )
    }

    @Test func doesNotHandOutExercisesDeletedAfterLoad() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let kept = Exercise(name: "ベンチプレス", bodyPart: .chest, defaultWeightUnit: .kg)
        let removed = Exercise(name: "重複したベンチプレス", bodyPart: .chest, defaultWeightUnit: .kg)
        context.insert(kept)
        context.insert(removed)
        try context.save()

        let viewModel = makeViewModel(context: context)
        viewModel.load()
        #expect(viewModel.exercises.count == 2)

        // 正規化が重複を消した状態を作る。ViewModelはまだload()し直していない。
        context.delete(removed)
        try context.save()

        // 画面はここで種目のプロパティに触れる。停止してはいけない。
        let names = viewModel.exercises.map(\.name)
        #expect(names == ["ベンチプレス"])
    }

    @Test func searchDoesNotTouchDeletedExercises() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let kept = Exercise(name: "スクワット", bodyPart: .legs, defaultWeightUnit: .kg)
        let removed = Exercise(name: "スクワット(重複)", bodyPart: .legs, defaultWeightUnit: .kg)
        context.insert(kept)
        context.insert(removed)
        try context.save()

        let viewModel = makeViewModel(context: context)
        viewModel.load()
        context.delete(removed)
        try context.save()

        #expect(viewModel.exercises(matching: "スクワット").map(\.name) == ["スクワット"])
    }
}
