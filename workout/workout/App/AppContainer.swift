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
            _ = exerciseRepository.addExercise(name: preset.name, bodyPart: preset.bodyPart)
        }
    }
}
