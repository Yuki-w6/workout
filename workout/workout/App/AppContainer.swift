@preconcurrency import Foundation
import SwiftData

@MainActor
final class AppContainer {
    let modelContainer: ModelContainer
    let exerciseRepository: ExerciseRepository

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        let modelContext = ModelContext(modelContainer)
        exerciseRepository = SwiftDataExerciseRepository(context: modelContext)
    }

    static func make(useCloud: Bool) async throws -> (container: AppContainer, warningMessage: String?) {
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
        let container = AppContainer(modelContainer: modelContainer)
        try normalizePresetExercisesIfNeeded(context: modelContainer.mainContext)
        return (container, nil)
    }

    private static func normalizePresetExercisesIfNeeded(context: ModelContext) throws {
        var exercises = try context.fetch(FetchDescriptor<Exercise>())
        guard exercises.isEmpty == false else { return }

        var records = try context.fetch(FetchDescriptor<RecordHeader>())
        var changed = false

        func updateRecordSnapshots(from oldID: UUID, to exercise: Exercise, source: Exercise? = nil) {
            for header in records {
                let idMatch = header.exerciseIDSnapshot == oldID
                let sourceMatch = source.map { header.exercise === $0 } ?? false
                guard idMatch || sourceMatch else { continue }
                header.exercise = exercise
                header.exerciseIDSnapshot = exercise.id
                header.exerciseNameSnapshot = exercise.name
                header.bodyPartRawSnapshot = exercise.bodyPartRaw
                header.defaultWeightUnitRawSnapshot = exercise.defaultWeightUnitRaw
                changed = true
            }
        }

        func moveTemplates(from source: Exercise, to target: Exercise) {
            guard let templates = source.templateSets else { return }
            for template in templates {
                template.exercise = target
                changed = true
            }
        }

        // まずは同一IDの重複を解消（並び順で参照が揺れないようにする）
        let groupedByID = Dictionary(grouping: exercises, by: { $0.id })
        for (_, group) in groupedByID where group.count > 1 {
            let canonical = group.first { $0.isPreset || $0.seedKey != nil } ?? group[0]
            for exercise in group where exercise !== canonical {
                if canonical.isPreset == false && (exercise.isPreset || exercise.seedKey != nil) {
                    canonical.isPreset = exercise.isPreset
                    canonical.seedKey = exercise.seedKey
                    canonical.seedVersion = exercise.seedVersion
                    canonical.presetSortKey = exercise.presetSortKey
                    changed = true
                }
                updateRecordSnapshots(from: exercise.id, to: canonical, source: exercise)
                moveTemplates(from: exercise, to: canonical)
                context.delete(exercise)
                changed = true
            }
        }

        if changed {
            try context.save()
            exercises = try context.fetch(FetchDescriptor<Exercise>())
            records = try context.fetch(FetchDescriptor<RecordHeader>())
            changed = false
        }

        var exerciseByID: [UUID: Exercise] = Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0) })

        for preset in PresetExerciseDefinitions.all {
            let matches = exercises.filter {
                $0.id == preset.id || $0.seedKey == preset.seedKey
            }
            guard matches.isEmpty == false else { continue }

            let canonical: Exercise
            if let existing = exerciseByID[preset.id] {
                canonical = existing
            } else {
                let created = Exercise(
                    id: preset.id,
                    name: preset.name,
                    bodyPart: preset.bodyPart,
                    defaultWeightUnit: preset.defaultWeightUnit,
                    isPreset: true,
                    seedKey: preset.seedKey,
                    seedVersion: preset.seedVersion,
                    isArchived: matches.allSatisfy { $0.isArchived }
                )
                context.insert(created)
                exerciseByID[preset.id] = created
                canonical = created
                changed = true
            }

            let shouldBeArchived = matches.allSatisfy { $0.isArchived }
            if canonical.isPreset == false ||
                canonical.seedKey != preset.seedKey ||
                canonical.seedVersion != preset.seedVersion ||
                canonical.name != preset.name ||
                canonical.bodyPartRaw != preset.bodyPart.rawValue ||
                canonical.defaultWeightUnitRaw != preset.defaultWeightUnit.rawValue ||
                canonical.presetSortKey != 0 ||
                canonical.isArchived != shouldBeArchived {
                canonical.isPreset = true
                canonical.seedKey = preset.seedKey
                canonical.seedVersion = preset.seedVersion
                canonical.name = preset.name
                canonical.bodyPartRaw = preset.bodyPart.rawValue
                canonical.defaultWeightUnitRaw = preset.defaultWeightUnit.rawValue
                canonical.presetSortKey = 0
                canonical.isArchived = shouldBeArchived
                changed = true
            }

            for exercise in matches where exercise.id != canonical.id {
                updateRecordSnapshots(from: exercise.id, to: canonical, source: exercise)
                moveTemplates(from: exercise, to: canonical)
                context.delete(exercise)
                changed = true
            }
        }

        // レコードの参照先が間違っている場合の修正（プリセット同士の誤結合だけ直す）
        let presetBySignature: [String: PresetExerciseDefinition] = Dictionary(
            uniqueKeysWithValues: PresetExerciseDefinitions.all.map {
                ("\($0.name)|\($0.bodyPart.rawValue)", $0)
            }
        )
        for header in records {
            guard let linked = header.exercise, linked.isPreset else { continue }
            let signature = "\(header.exerciseNameSnapshot)|\(header.bodyPartRawSnapshot)"
            guard let preset = presetBySignature[signature] else { continue }
            guard preset.id != header.exerciseIDSnapshot else { continue }
            if let target = exerciseByID[preset.id] {
                header.exercise = target
                header.exerciseIDSnapshot = target.id
                changed = true
            }
        }

        if changed {
            try context.save()
        }
    }
}
