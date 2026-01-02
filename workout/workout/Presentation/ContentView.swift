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
                    Label("Home", systemImage: "house")
                }
            RecordListView()
                .tabItem {
                    Label("History", systemImage: "clock.arrow.circlepath")
                }
        }
    }
}

struct ExerciseListView: View {
    @ObservedObject var viewModel: ExerciseListViewModel

    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.exercises, id: \.id) { exercise in
                    NavigationLink {
                        ExerciseDetailView(viewModel: viewModel, exerciseID: exercise.id)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(exercise.name)
                                .font(.headline)
                            Text(exercise.bodyPart.rawValue)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete(perform: viewModel.deleteExercises)
            }
            .navigationTitle("Home")
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

struct RecordListView: View {
    private let recordNames = ["Today", "Yesterday", "Last Week"]

    var body: some View {
        NavigationStack {
            List(recordNames, id: \.self) { recordName in
                Text(recordName)
            }
            .navigationTitle("History")
        }
    }
}

struct ExerciseDetailView: View {
    @ObservedObject var viewModel: ExerciseListViewModel
    let exerciseID: UUID
    @State private var isEditing = false
    @State private var draftName = ""
    @State private var draftBodyPart: BodyPart = .fullBody

    private var currentExercise: Exercise? {
        viewModel.exercise(id: exerciseID)
    }

    var body: some View {
        List {
            Section("Name") {
                Text(currentExercise?.name ?? "Unknown")
                    .accessibilityIdentifier("ExerciseName")
            }
            Section("Body Part") {
                Text(currentExercise?.bodyPart.rawValue ?? "Unknown")
                    .accessibilityIdentifier("ExerciseBodyPart")
            }
        }
        .navigationTitle("Exercise")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit") {
                    draftName = currentExercise?.name ?? ""
                    draftBodyPart = currentExercise?.bodyPart ?? .fullBody
                    isEditing = true
                }
            }
        }
        .sheet(isPresented: $isEditing) {
            NavigationStack {
                Form {
                    TextField("Exercise Name", text: $draftName)
                    Picker("Body Part", selection: $draftBodyPart) {
                        ForEach(BodyPart.allCases, id: \.self) { bodyPart in
                            Text(bodyPart.rawValue)
                        }
                    }
                }
                .navigationTitle("Edit Exercise")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            isEditing = false
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            viewModel.updateExercise(
                                id: exerciseID,
                                name: draftName,
                                bodyPart: draftBodyPart
                            )
                            isEditing = false
                        }
                    }
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
        deleteExercise: DeleteExerciseUseCase(repository: repository)
    )
    return ContentView(viewModel: viewModel)
}
