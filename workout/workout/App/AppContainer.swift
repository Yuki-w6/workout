import Foundation
import SwiftData

final class AppContainer {
    let modelContainer: ModelContainer
    let exerciseRepository: ExerciseRepository

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        let modelContext = ModelContext(modelContainer)
        exerciseRepository = SwiftDataExerciseRepository(modelContext: modelContext)
    }

    static func make() throws -> AppContainer {
        let schema = Schema([Exercise.self, ExerciseSet.self, RecordHeader.self, RecordDetail.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        let modelContainer = try ModelContainer(for: schema, configurations: [configuration])
        seedExercisesIfNeeded(using: modelContainer)
        return AppContainer(modelContainer: modelContainer)
    }

    private static func seedExercisesIfNeeded(using modelContainer: ModelContainer) {
        let modelContext = ModelContext(modelContainer)
        let repository = SwiftDataExerciseRepository(modelContext: modelContext)
        guard repository.fetchAll().isEmpty else {
            return
        }
        let presets: [(name: String, bodyPart: BodyPart)] = [
            ("ベンチプレス", .chest),
            ("チェストプレス", .chest),
            ("デットリフト", .back),
            ("ラットプルダウン", .back),
            ("スクワット", .legs),
            ("レッグプレス", .legs),
            ("ショルダープレス", .shoulders),
            ("サイドレイズ", .shoulders),
            ("リアレイズ", .shoulders),
            ("アームカール", .arms),
            ("ヒップスラスト", .glutes),
            ("アブドミナル", .core)
        ]

        for preset in presets {
            _ = repository.addExercise(name: preset.name, bodyPart: preset.bodyPart)
        }
    }
}
