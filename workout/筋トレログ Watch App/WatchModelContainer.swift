import Foundation
import SwiftData
import WorkoutShared

enum WatchModelContainer {
    static func make() throws -> ModelContainer {
        let schema = Schema([Exercise.self, ExerciseTemplateSet.self, RecordHeader.self, RecordSet.self])
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .private("iCloud.com.mayamayk.workoutlog")
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
