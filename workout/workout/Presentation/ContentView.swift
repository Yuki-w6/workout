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
                    VStack(spacing: 2) {
                        Image(systemName: "house")
                        Text("ホーム")
                    }
                }
            RecordListView(viewModel: viewModel)
                .tabItem {
                    VStack(spacing: 2) {
                        Image(systemName: "calendar")
                        Text("記録")
                    }
                }
            GraphView(viewModel: viewModel)
                .tabItem {
                    VStack(spacing: 2) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                        Text("グラフ")
                    }
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
