import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel: ExerciseListViewModel

    init(viewModel: ExerciseListViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        TabView {
            ExerciseListView(viewModel: viewModel)
                .tabItem {
                    Image(systemName: "house")
                        .accessibilityLabel("ホーム")
                }
            RecordListView(viewModel: viewModel)
                .tabItem {
                    Image(systemName: "calendar")
                        .accessibilityLabel("履歴")
                }
            GraphView(viewModel: viewModel)
                .tabItem {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .accessibilityLabel("グラフ")
                }
        }
    }
}

#Preview {
    let repository = InMemoryExerciseRepository()
    let viewModel = ExerciseListViewModel(
        fetchExercises: FetchExercisesUseCase(repository: repository),
        fetchExercise: FetchExerciseUseCase(repository: repository),
        addExercise: AddExerciseUseCase(repository: repository),
        updateExercise: UpdateExerciseUseCase(repository: repository),
        updateExerciseRecord: UpdateExerciseRecordUseCase(repository: repository),
        deleteExercise: DeleteExerciseUseCase(repository: repository)
    )
    return ContentView(viewModel: viewModel)
}
