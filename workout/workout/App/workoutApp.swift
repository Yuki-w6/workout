import SwiftUI

@main
struct workoutApp: App {
    private let container = AppContainer.shared

    var body: some Scene {
        WindowGroup {
            let repository = container.exerciseRepository
            let viewModel = ExerciseListViewModel(
                fetchExercises: FetchExercisesUseCase(repository: repository),
                fetchExercise: FetchExerciseUseCase(repository: repository),
                addExercise: AddExerciseUseCase(repository: repository),
                updateExercise: UpdateExerciseUseCase(repository: repository),
                deleteExercise: DeleteExerciseUseCase(repository: repository)
            )
            ContentView(viewModel: viewModel)
        }
    }
}
