import SwiftData
@testable import WorkoutShared

func makeTestContainer() throws -> ModelContainer {
    let schema = Schema([
        Exercise.self,
        ExerciseTemplateSet.self,
        RecordHeader.self,
        RecordSet.self,
    ])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    return try ModelContainer(for: schema, configurations: [configuration])
}
