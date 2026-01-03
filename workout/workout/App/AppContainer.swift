import Foundation
import SwiftData

@MainActor
final class AppContainer {
    static let shared = AppContainer()

    let modelContainer: ModelContainer
    let exerciseRepository: ExerciseRepository

    private init() {
        let schema = Schema([Exercise.self, ExerciseSet.self, RecordHeader.self, RecordDetail.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            modelContainer = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
        let modelContext = ModelContext(modelContainer)
        exerciseRepository = SwiftDataExerciseRepository(modelContext: modelContext)
        seedExercisesIfNeeded()
    }

    private func seedExercisesIfNeeded() {
        guard exerciseRepository.fetchAll().isEmpty else {
            return
        }
        _ = exerciseRepository.addExercise(name: "Bench Press", bodyPart: .chest)
        _ = exerciseRepository.addExercise(name: "Deadlift", bodyPart: .back)
        _ = exerciseRepository.addExercise(name: "Squat", bodyPart: .legs)
    }
}
