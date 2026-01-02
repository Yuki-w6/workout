import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel: ExerciseListViewModel

    init(viewModel: ExerciseListViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.exercises, id: \.id) { exercise in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(exercise.name)
                            .font(.headline)
                        Text(exercise.bodyPart.rawValue)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Exercises")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: viewModel.addSampleExercise) {
                        Label("Add", systemImage: "plus")
                    }
                }
            }
            .onAppear {
                viewModel.load()
            }
        }
    }
}

#Preview {
    let repository = InMemoryExerciseRepository()
    let viewModel = ExerciseListViewModel(
        fetchExercises: FetchExercisesUseCase(repository: repository),
        addExercise: AddExerciseUseCase(repository: repository)
    )
    return ContentView(viewModel: viewModel)
}
