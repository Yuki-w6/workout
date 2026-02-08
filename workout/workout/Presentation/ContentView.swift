import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel: ExerciseListViewModel
    @Binding private var isCloudSyncEnabled: Bool

    init(viewModel: ExerciseListViewModel, isCloudSyncEnabled: Binding<Bool>) {
        _viewModel = StateObject(wrappedValue: viewModel)
        _isCloudSyncEnabled = isCloudSyncEnabled
    }

    var body: some View {
        TabView {
            ExerciseListView(viewModel: viewModel, isCloudSyncEnabled: $isCloudSyncEnabled)
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

private struct ContentViewPreview: View {
    private let container: ModelContainer
    private let viewModel: ExerciseListViewModel

    init() {
        let schema = Schema([Exercise.self, ExerciseTemplateSet.self, RecordHeader.self, RecordSet.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)

        let exercises = PresetExerciseDefinitions.all.map { preset in
            Exercise(
                id: preset.id,
                name: preset.name,
                bodyPart: preset.bodyPart,
                defaultWeightUnit: preset.defaultWeightUnit,
                isPreset: true,
                seedKey: preset.seedKey,
                seedVersion: preset.seedVersion
            )
        }
        exercises.forEach { context.insert($0) }

        let calendar = Calendar(identifier: .gregorian)
        if let benchPress = exercises.first(where: { $0.seedKey == "bench_press" }) {
            func addRecord(dayOffset: Int, sets: [(Double, Int)]) {
                guard let date = calendar.date(byAdding: .day, value: dayOffset, to: Date()) else {
                    return
                }
                let startDate = calendar.startOfDay(for: date)
                let header = RecordHeader(date: startDate, exercise: benchPress)
                context.insert(header)
                let recordSets = sets.enumerated().map { index, set in
                    RecordSet(
                        setNumber: index + 1,
                        weight: set.0,
                        weightUnit: .kg,
                        repetitions: set.1,
                        header: header
                    )
                }
                recordSets.forEach { context.insert($0) }
                header.sets = recordSets
            }

            addRecord(dayOffset: -14, sets: [(50, 10), (50, 10), (50, 8)])
            addRecord(dayOffset: -10, sets: [(55, 10), (55, 8), (55, 8)])
            addRecord(dayOffset: -7, sets: [(60, 8), (60, 8), (60, 6)])
            addRecord(dayOffset: -3, sets: [(62.5, 8), (62.5, 7), (62.5, 6)])
            addRecord(dayOffset: -1, sets: [(65, 6), (65, 6), (65, 5)])
        }

        try? context.save()

        let repository = SwiftDataExerciseRepository(context: context)
        let viewModel = ExerciseListViewModel(
            fetchExercises: FetchExercisesUseCase(repository: repository),
            fetchExercise: FetchExerciseUseCase(repository: repository),
            addExercise: AddExerciseUseCase(repository: repository),
            updateExercise: UpdateExerciseUseCase(repository: repository),
            deleteExercise: DeleteExerciseUseCase(repository: repository)
        )

        self.container = container
        self.viewModel = viewModel
    }

    var body: some View {
        ContentView(viewModel: viewModel, isCloudSyncEnabled: .constant(true))
            .modelContainer(container)
    }
}

#Preview {
    ContentViewPreview()
}
