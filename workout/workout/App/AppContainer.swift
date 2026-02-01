@preconcurrency import Foundation
import SwiftData

final class AppContainer {
    let modelContainer: ModelContainer
    let exerciseRepository: ExerciseRepository

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        let modelContext = ModelContext(modelContainer)
        exerciseRepository = SwiftDataExerciseRepository(context: modelContext)
    }

    static func make(useCloud: Bool) throws -> (container: AppContainer, warningMessage: String?) {
        let schema = Schema([Exercise.self, ExerciseTemplateSet.self, RecordHeader.self, RecordSet.self])
        let configuration: ModelConfiguration
        if useCloud {
            configuration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .private("iCloud.com.mayamayk.workoutlog")
            )
        } else {
            configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        }
        let modelContainer = try ModelContainer(for: schema, configurations: [configuration])
        return (AppContainer(modelContainer: modelContainer), nil)
    }
}
